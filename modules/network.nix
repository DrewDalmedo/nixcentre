# The home network. The ThinkCentre's Ethernet port (plus the Wi-Fi hotspot, if
# enabled) forms a bridge, br0, at 10.10.10.1. dnsmasq hands out addresses and
# names on it. A USB-tethered phone, when plugged in, is the server's internet.
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

    networks."30-tether" = {
      matchConfig.Driver = tetherDrivers;
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
      }
      // lib.optionalAttrs cfg.shareTetheredInternet {
        IPv4Forwarding = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  # iPhone USB tethering needs usbmuxd to pair ("Trust This Computer?").
  services.usbmuxd.enable = true;

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
