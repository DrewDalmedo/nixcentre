# nixcentre.fakeInternet: answer the "is there internet?" checks that phones,
# tablets and computers make when they join a network, so they treat the home
# network as connected. The trade-off is that phones then send everything over
# Wi-Fi instead of mobile data. Off by default.
#
# Best effort: modern Android also checks over HTTPS, which can't be faked, so it
# may ask once whether to stay on a network with "limited connectivity".
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcentre;
  homepage = "http://${config.networking.hostName}.${cfg.domain}/";

  appleSuccess = "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>\n";

  # The exact answers each operating system expects, served as files at the
  # paths they ask for.
  answers = pkgs.linkFarm "connectivity-check-answers" (
    lib.mapAttrsToList
      (path: text: {
        name = path;
        path = pkgs.writeText (baseNameOf path) text;
      })
      {
        # Apple (iOS, macOS)
        "hotspot-detect.html" = appleSuccess;
        "library/test/success.html" = appleSuccess;
        # Windows
        "connecttest.txt" = "Microsoft Connect Test";
        "ncsi.txt" = "Microsoft NCSI";
        # Firefox
        "success.txt" = "success\n";
        "canonical.html" =
          ''<meta http-equiv="refresh" content="0;url=https://support.mozilla.org/kb/captive-portal"/>'';
        # NetworkManager (GNOME, Arch)
        "check_network_status.txt" = "NetworkManager is online\n";
        "nm-check.txt" = "NetworkManager is online\n";
      }
  );

  checkHosts = [
    # Android, ChromeOS
    "connectivitycheck.gstatic.com"
    "connectivitycheck.android.com"
    "clients1.google.com"
    "clients3.google.com"
    "www.google.com"
    "www.gstatic.com"
    "play.googleapis.com"
    "connect.rom.miui.com"
    "connectivitycheck.platform.hicloud.com"
    # Apple
    "captive.apple.com"
    "www.apple.com"
    # Windows
    "www.msftconnecttest.com"
    "www.msftncsi.com"
    # Firefox
    "detectportal.firefox.com"
    # NetworkManager
    "nmcheck.gnome.org"
    "ping.archlinux.org"
  ];

  # Ubuntu expects "204 No Content" plus a header, at the root path.
  ubuntuHost = "connectivity-check.ubuntu.com";

  dnsList = hosts: "/${lib.concatStringsSep "/" hosts}/";
in
lib.mkIf cfg.fakeInternet {
  services.dnsmasq.settings = {
    # Point the check hosts at this server; `local` makes their IPv6 lookups come
    # back empty instead of failing.
    address = [
      "${dnsList (checkHosts ++ [ ubuntuHost ])}${cfg.lan.address}"
      # Windows also checks that this name resolves to exactly this address.
      "/dns.msftncsi.com/131.107.255.255"
    ];
    local = [ (dnsList (checkHosts ++ [ ubuntuHost ] ++ [ "dns.msftncsi.com" ])) ];
  };

  services.caddy.virtualHosts = {
    ${lib.concatMapStringsSep ", " (host: "http://${host}") checkHosts} = {
      # The default log file is named after the site, which here is far too long.
      logFormat = "output discard";
      extraConfig = ''
        @noContent path /generate_204 /gen_204
        handle @noContent {
          respond 204
        }

        @answer {
          not path */
          file {
            root ${answers}
          }
        }
        handle @answer {
          root * ${answers}
          file_server
        }

        # Anything else on these sites (say, typing google.com) leads home.
        handle {
          redir ${homepage}
        }
      '';
    };

    "http://${ubuntuHost}" = {
      logFormat = "output discard";
      extraConfig = ''
        header X-NetworkManager-Status online
        respond 204
      '';
    };
  };
}
