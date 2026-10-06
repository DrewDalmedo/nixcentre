# Boots the server in a VM next to a "laptop" on the same network and checks the
# whole setup end to end: DHCP and DNS, the homepage, every app by name and by
# port, Wikipedia from a ZIM file dropped into the folder, the shared folder, and
# both settings of nixcentre.fakeInternet.
#
# Run with `nix flake check` or `nix build .#checks.x86_64-linux.vm -L`.
{ lib, pkgs, ... }:
let
  # A one-page ZIM file to feed to Kiwix.
  testZim = pkgs.runCommand "test.zim" { nativeBuildInputs = [ pkgs.zim-tools ]; } ''
    mkdir html
    echo '<!doctype html><html><head><meta charset="utf-8"><title>Test</title></head><body><h1>Hello from nixcentre</h1></body></html>' > html/index.html
    echo 'iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAIAAADYYG7QAAAAQklEQVR4nO3OQQ0AIAwAsUlCEtKQiguOR5MK6Kx9vjL5QEhISKgeCAkJCdUDISEhoXogJCQkVA+EhISE6oGQkNBjFy6zsJeSP++oAAAAAElFTkSuQmCC' | base64 -d > html/icon.png
    zimwriterfs --welcome=index.html --illustration=icon.png --language=eng \
      --title=Test --description="Test ZIM" --creator=nixcentre --publisher=nixcentre \
      --name=nixcentre_test html $out
  '';
in
{
  name = "nixcentre";

  nodes.server = {
    imports = [ ../hosts/nixcentre ];
    virtualisation.interfaces.enlan0.vlan = 1;
    # Only this port: the VM's built-in NIC (eth0) has an `en*` alternative name,
    # which the default pattern would match too.
    nixcentre.lan.ports = [ "enlan0" ];
    virtualisation.memorySize = 4096;
    virtualisation.cores = 4;
    virtualisation.diskSize = 4096;
    specialisation.fake-internet.configuration.nixcentre.fakeInternet = lib.mkForce true;
  };

  nodes.laptop =
    { pkgs, ... }:
    {
      # A unique name: plain ethN names collide with the VM's built-in NIC.
      virtualisation.interfaces.lan0.vlan = 1;
      networking.useNetworkd = true;
      networking.useDHCP = false;
      systemd.network.networks."10-lan" = {
        matchConfig.Name = "lan0";
        networkConfig.DHCP = "ipv4";
      };
      services.avahi = {
        enable = true;
        nssmdns4 = true;
      };
      environment.systemPackages = [
        pkgs.curl
        pkgs.samba
      ];
    };

  testScript = ''
    import time

    # Addresses dnsmasq hands out: .100 to .250.
    LEASE = r"10\.10\.10\.(1[0-9][0-9]|2[0-4][0-9]|250)"

    start_all()

    with subtest("the server sets up the home network"):
        server.wait_for_unit("multi-user.target")
        server.wait_for_unit("dnsmasq.service")
        server.wait_for_unit("caddy.service")
        server.succeed("ip -4 addr show br0 | grep -q 'inet 10.10.10.1/24'")
        server.succeed("bridge link show | grep -q 'enlan0.*master br0'")

    with subtest("the laptop gets an address, a gateway and DNS"):
        laptop.wait_for_unit("multi-user.target")
        laptop.wait_until_succeeds(f"ip -4 addr show lan0 | grep -qE 'inet {LEASE}/24'")
        laptop.succeed("ip route | grep -q 'default via 10.10.10.1'")

    with subtest("home names resolve, internet names fail fast"):
        for name in ["nixcentre.home.arpa", "home.arpa", "wiki.home.arpa", "tv.home.arpa", "nixcentre"]:
            laptop.succeed(f"getent ahostsv4 {name} | grep -q '^10.10.10.1 '")
        laptop.succeed(f"getent ahostsv4 laptop.home.arpa | grep -qE '^{LEASE} '")
        laptop.wait_until_succeeds("getent ahostsv4 nixcentre.local | grep -q '^10.10.10.1 '")
        start = time.monotonic()
        laptop.fail("getent hosts example.com")
        laptop.fail("getent hosts connectivitycheck.gstatic.com")
        assert time.monotonic() - start < 10, "internet lookups should fail quickly"

    with subtest("the homepage answers on every address"):
        for url in ["http://10.10.10.1/", "http://nixcentre.home.arpa/", "http://nixcentre.local/"]:
            laptop.succeed(f"curl -sf {url} | grep -q 'Movies &amp; TV'")

    with subtest("a ZIM file dropped into the folder shows up in Kiwix"):
        server.wait_for_unit("kiwix-serve.service")
        laptop.wait_until_succeeds("curl -sf http://wiki.home.arpa/ > /dev/null")
        server.succeed("cp ${testZim} /srv/media/wikipedia/test.zim")
        laptop.wait_until_succeeds(
            "curl -sf http://wiki.home.arpa/content/test/index.html | grep -q 'Hello from nixcentre'",
            timeout=120,
        )
        laptop.succeed("curl -sf http://10.10.10.1:8080/content/test/index.html | grep -q 'Hello from nixcentre'")

    with subtest("Jellyfin, Kavita and Audiobookshelf answer by name and by port"):
        laptop.wait_until_succeeds("curl -sf http://tv.home.arpa/System/Info/Public | grep -q ServerName", timeout=900)
        laptop.succeed("curl -sf http://10.10.10.1:8096/System/Info/Public | grep -q ServerName")
        laptop.wait_until_succeeds("curl -sfL http://books.home.arpa/ | grep -qi kavita", timeout=900)
        laptop.succeed("curl -sfL http://10.10.10.1:5000/ | grep -qi kavita")
        laptop.wait_until_succeeds("curl -sfL http://audiobooks.home.arpa/ | grep -qi audiobookshelf", timeout=900)
        laptop.succeed("curl -sfL http://10.10.10.1:8000/ | grep -qi audiobookshelf")

    with subtest("the shared folder takes your files and nobody else's"):
        server.succeed("(echo secret; echo secret) | smbpasswd -s -a drew")
        laptop.succeed("echo hello > /tmp/hello.txt")
        laptop.succeed("smbclient //nixcentre.home.arpa/media -U drew%secret -c 'cd books; put /tmp/hello.txt hello.txt'")
        server.succeed("test $(stat -c %G /srv/media/books/hello.txt) = media")
        # Every app runs as its own user, so files must be readable by others.
        server.succeed("su -s /bin/sh nobody -c 'cat /srv/media/books/hello.txt' | grep -q hello")
        laptop.fail("smbclient //nixcentre.home.arpa/media -N -c ls")
        laptop.fail("smbclient //nixcentre.home.arpa/media -U drew%wrong -c ls")

    with subtest("internet checks fail by default and pass with fakeInternet"):
        laptop.fail("curl -sf -m 5 http://connectivitycheck.gstatic.com/generate_204")
        server.succeed("/run/current-system/specialisation/fake-internet/bin/switch-to-configuration test")
        laptop.succeed("resolvectl flush-caches")
        laptop.wait_until_succeeds("getent ahostsv4 connectivitycheck.gstatic.com | grep -q '^10.10.10.1 '")
        laptop.succeed("test $(curl -s -o /dev/null -w '%{http_code}' http://connectivitycheck.gstatic.com/generate_204) = 204")
        laptop.succeed("test $(curl -s -o /dev/null -w '%{http_code}' http://clients3.google.com/generate_204) = 204")
        laptop.succeed("curl -sf http://captive.apple.com/hotspot-detect.html | grep -q '<BODY>Success</BODY>'")
        laptop.succeed("test \"$(curl -sf http://www.msftconnecttest.com/connecttest.txt)\" = 'Microsoft Connect Test'")
        laptop.succeed("getent ahostsv4 dns.msftncsi.com | grep -q '^131.107.255.255 '")
        laptop.succeed("printf 'success\\n' > /tmp/expected && curl -sf http://detectportal.firefox.com/success.txt > /tmp/got && cmp /tmp/got /tmp/expected")
        laptop.succeed("curl -si http://connectivity-check.ubuntu.com/ | grep -qi '^x-networkmanager-status: online'")
        laptop.succeed("curl -s -o /dev/null -w '%{redirect_url}' http://www.google.com/search | grep -q '^http://nixcentre.home.arpa/'")
        # Home services keep working in this mode.
        laptop.succeed("curl -sf http://wiki.home.arpa/content/test/index.html | grep -q 'Hello from nixcentre'")
  '';
}
