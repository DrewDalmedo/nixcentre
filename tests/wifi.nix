# Wi-Fi, with simulated radios (mac80211_hwsim), each VM getting two:
#
# - hotspot: the server joins a phone's Wi-Fi hotspot to get online, using the
#   same `iwctl` command as in docs/using.md. The phone is played by the first
#   radio in its own network namespace, running hostapd and a DHCP server with
#   an iPhone's addresses.
# - accesspoint: with nixcentre.wifi.enable, the server broadcasts its own
#   network, and a laptop (the second radio, in its own namespace) joins it and
#   gets an address from the home network.
#
# Run with `nix build .#checks.x86_64-linux.wifi -L`.
{ lib, pkgs, ... }:
let
  common = {
    imports = [ ../hosts/nixcentre ];
    boot.kernelModules = [ "mac80211_hwsim" ];
    # No wired network at all, so the VM's built-in NIC stays out of the bridge.
    virtualisation.vlans = [ ];
    nixcentre.lan.ports = [ "no-wired-ports" ];
    virtualisation.memorySize = 2048;
    # This test is about Wi-Fi; don't spend the slow emulated CPU on these.
    systemd.services.jellyfin.wantedBy = lib.mkForce [ ];
    systemd.services.kavita.wantedBy = lib.mkForce [ ];
    systemd.services.audiobookshelf.wantedBy = lib.mkForce [ ];
  };

  phoneHotspot = pkgs.writeText "phone-hotspot.conf" ''
    interface=wlan0
    driver=nl80211
    ssid=Test iPhone
    hw_mode=g
    channel=1
    wpa=2
    wpa_key_mgmt=WPA-PSK
    rsn_pairwise=CCMP
    wpa_passphrase=hotspot-password
  '';

  laptopWifi = pkgs.writeText "laptop-wpa.conf" ''
    network={
      ssid="nixcentre"
      psk="home-wifi-password"
    }
  '';

  # Puts the address from DHCP on the interface (busybox udhcpc calls this).
  udhcpcScript = pkgs.writeShellScript "udhcpc-script" ''
    case "$1" in
      bound|renew) ${pkgs.iproute2}/bin/ip addr replace "$ip/$mask" dev "$interface" ;;
    esac
  '';
in
{
  name = "nixcentre-wifi";

  nodes.hotspot = common;

  nodes.accesspoint = {
    imports = [ common ];
    nixcentre.wifi = {
      enable = lib.mkForce true;
      interface = lib.mkForce "wlan0";
    };
    systemd.tmpfiles.settings."10-wifi-password" = {
      "/var/lib/nixcentre".d.mode = "0700";
      "/var/lib/nixcentre/wifi-password".f = {
        mode = "0600";
        argument = "home-wifi-password";
      };
    };
  };

  testScript = ''
    with subtest("the server gets online through a phone's Wi-Fi hotspot"):
        hotspot.start()
        hotspot.wait_for_unit("multi-user.target")
        hotspot.wait_for_unit("iwd.service")
        hotspot.succeed(
            "ip netns add phone",
            "iw phy phy0 set netns name phone",
            "ip -n phone addr add 172.20.10.1/28 dev wlan0",
            "ip netns exec phone ${pkgs.hostapd}/bin/hostapd -B ${phoneHotspot}",
            "ip netns exec phone ${pkgs.dnsmasq}/bin/dnsmasq --conf-file=/dev/null"
            " --interface=wlan0 --bind-interfaces --port=0"
            " --dhcp-range=172.20.10.2,172.20.10.14,1h"
            " --dhcp-option=option:router,172.20.10.1 --dhcp-option=option:dns-server,172.20.10.1"
            " --dhcp-leasefile=/tmp/phone.leases --pid-file=/tmp/phone-dnsmasq.pid",
        )
        hotspot.wait_until_succeeds(
            "iwctl station wlan1 scan; sleep 3; iwctl station wlan1 get-networks | grep 'Test iPhone' > /dev/null",
            timeout=180,
        )
        hotspot.succeed("iwctl --passphrase hotspot-password station wlan1 connect 'Test iPhone'")
        hotspot.wait_until_succeeds("ip -4 addr show wlan1 | grep 'inet 172.20.10.' > /dev/null", timeout=120)
        hotspot.succeed("ip route show default | grep 'via 172.20.10.1 dev wlan1' > /dev/null")
        hotspot.succeed("resolvectl dns wlan1 | grep 172.20.10.1 > /dev/null")

    with subtest("the apps stay closed to the phone's network"):
        addr = hotspot.succeed("ip -4 -o addr show wlan1 | awk '{print $4}' | cut -d/ -f1").strip()
        hotspot.succeed(f"ip netns exec phone ping -c 1 -W 5 {addr}")
        hotspot.fail(f"ip netns exec phone ${pkgs.curl}/bin/curl -sf -m 5 http://{addr}/")
        hotspot.fail(f"ip netns exec phone ${pkgs.curl}/bin/curl -sf -m 5 http://{addr}:8080/")
        hotspot.succeed("curl -sf http://10.10.10.1/ | grep 'Movies &amp; TV' > /dev/null")
        hotspot.shutdown()

    with subtest("with wifi.enable, the server broadcasts the home network"):
        accesspoint.start()
        accesspoint.wait_for_unit("multi-user.target")
        accesspoint.wait_for_unit("hostapd.service")
        accesspoint.fail("systemctl is-active iwd.service")
        accesspoint.wait_until_succeeds("bridge link show | grep 'wlan0.*master br0' > /dev/null")
        accesspoint.succeed(
            "ip netns add laptop",
            "iw phy phy1 set netns name laptop",
            "ip netns exec laptop ${pkgs.wpa_supplicant}/bin/wpa_supplicant -B -i wlan1 -c ${laptopWifi}",
        )
        accesspoint.wait_until_succeeds("ip netns exec laptop iw dev wlan1 link | grep 'SSID: nixcentre' > /dev/null", timeout=120)
        accesspoint.succeed("ip netns exec laptop ${pkgs.busybox}/bin/udhcpc -i wlan1 -n -q -t 20 -s ${udhcpcScript}")
        accesspoint.succeed("ip -n laptop -4 addr show wlan1 | grep 'inet 10.10.10.' > /dev/null")
        accesspoint.succeed("ip netns exec laptop ${pkgs.curl}/bin/curl -sf http://10.10.10.1/ | grep 'Movies &amp; TV' > /dev/null")
  '';
}
