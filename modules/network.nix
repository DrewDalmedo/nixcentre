# The home network. The ThinkCentre's Ethernet port (plus the Wi-Fi hotspot, if
# enabled) forms a bridge, br0, at 10.10.10.1. dnsmasq hands out addresses and
# names on it. A phone is the server's internet, when you connect one: over USB
# (tethering) or through its Wi-Fi hotspot.
{
  config,
  lib,
  ...
}:
let
  cfg = config.nixcentre;
  inherit (cfg.lan) address subnet;
  lan = cfg.lan.interface;
  hostName = config.networking.hostName;

  # USB tethering: Android (RNDIS, NCM, ECM) and iPhone.
  tetherDrivers = lib.concatStringsSep " " [
    "rndis_host"
    "cdc_ncm"
    "cdc_ether"
    "ipheth"
  ];

  # How the server uses a phone's connection: DHCP, plus forwarding when it's
  # shared with the home network.
  uplink = {
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    }
    // lib.optionalAttrs cfg.shareTetheredInternet {
      IPv4Forwarding = true;
    };
    linkConfig.RequiredForOnline = "no";
  };

  # The Wi-Fi card can join a phone's hotspot, unless it's busy being the home
  # network's own hotspot (wifi-ap.nix): one card can't do both.
  wifiUplink = !cfg.wifi.enable;
in
{
  networking = {
    useNetworkd = true;
    useDHCP = false;
    firewall.interfaces.${lan} = {
      allowedTCPPorts = [
        22 # SSH
        53 # DNS
      ];
      allowedUDPPorts = [
        53 # DNS
        67 # DHCP
        123 # time (chrony)
        5353 # mDNS: nixcentre.local
      ];
    };
  };

  systemd.network = {
    enable = true;
    # Waiting for "online" would stall every boot: there's no internet to wait for.
    wait-online.enable = false;

    netdevs."10-${lan}".netdevConfig = {
      Kind = "bridge";
      Name = lan;
    };

    networks."10-${lan}" = {
      matchConfig.Name = lan;
      address = [ "${address}/24" ];
      networkConfig = {
        # Keep the address (and DNS/DHCP) up even with nothing plugged in yet.
        ConfigureWithoutCarrier = true;
        IPv6AcceptRA = false;
      }
      // lib.optionalAttrs cfg.shareTetheredInternet {
        IPMasquerade = "ipv4";
      };
      linkConfig.RequiredForOnline = "no";
    };

    networks."20-lan-ports" = {
      matchConfig = {
        Name = lib.concatStringsSep " " cfg.lan.ports;
        Driver = "!${tetherDrivers}";
      };
      networkConfig.Bridge = lan;
      linkConfig.RequiredForOnline = "no";
    };

    networks."30-tether" = uplink // {
      matchConfig.Driver = tetherDrivers;
    };

    networks."40-wifi-uplink" = lib.mkIf wifiUplink (
      uplink
      // {
        matchConfig.WLANInterfaceType = "station";
      }
    );
  };

  # iPhone USB tethering needs usbmuxd to pair ("Trust This Computer?").
  services.usbmuxd.enable = true;

  # Joining a phone's hotspot: `iwctl station wlp1s0 connect "Your iPhone"`
  # (see docs/using.md). iwd only joins the network; networkd does the rest.
  networking.wireless.iwd = lib.mkIf wifiUplink {
    enable = true;
    settings = {
      General.EnableNetworkConfiguration = false;
      # Keep the kernel's name for the card (e.g. wlp1s0) instead of iwd's own.
      DriverQuirks.DefaultInterface = "*";
    };
  };

  # systemd-resolved answers the server's own lookups, using the phone's DNS while
  # tethered. Avahi does mDNS, so keep resolved out of its way.
  services.resolved.settings.Resolve.MulticastDNS = false;

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      interface = lan;
      bind-dynamic = true;

      # DNS: everything under the home domain points at this server; device names
      # from DHCP (e.g. laptop.home.arpa) take precedence.
      no-resolv = true;
      no-hosts = true;
      domain-needed = true;
      bogus-priv = true;
      inherit (cfg) domain;
      local = [ "/${cfg.domain}/" ];
      address = [ "/${cfg.domain}/${address}" ];
      host-record = [ "${hostName},${hostName}.${cfg.domain},${address}" ];
      cache-size = 1000;
      # Other names fail straight away, so devices quickly see there's no internet.
      # When sharing a tethered phone's internet, pass them on instead.
      server = lib.optionals cfg.shareTetheredInternet [ "127.0.0.53" ];

      # DHCP. Android won't stay on a network that doesn't offer a gateway.
      dhcp-range = [ "${subnet}.100,${subnet}.250,255.255.255.0,12h" ];
      dhcp-option = [
        "option:router,${address}"
        "option:dns-server,${address}"
        "option:ntp-server,${address}"
        "option:domain-search,${cfg.domain}"
      ];
      dhcp-authoritative = true;
      dhcp-rapid-commit = true;
    };
  };

  # nixcentre.local, for devices that ask their mobile network for DNS.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    allowInterfaces = [ lan ];
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };
}
