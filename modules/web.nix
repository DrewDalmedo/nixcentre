# The front door: Caddy serves the homepage on every name and on the bare IP
# address, and gives each app its own name (wiki.home.arpa, tv.home.arpa, ...).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcentre;
  homepage = import ./homepage.nix { inherit config lib pkgs; };
in
{
  services.caddy = {
    enable = true;
    # Plain HTTP: no certificates to install on every device, and nothing tries to
    # reach Let's Encrypt.
    globalConfig = ''
      auto_https off
    '';
    virtualHosts = {
      ":80".extraConfig = ''
        root * ${homepage}
        file_server
      '';
    }
    // lib.mapAttrs' (
      _: app:
      lib.nameValuePair "http://${app.subdomain}.${cfg.domain}" {
        extraConfig = "reverse_proxy 127.0.0.1:${toString app.port}";
      }
    ) cfg.apps;
  };

  # Apps are also reachable directly at 10.10.10.1:<port>, which works even when a
  # phone sends its DNS lookups over mobile data.
  networking.firewall.interfaces.${cfg.lan.interface}.allowedTCPPorts = [
    80
  ]
  ++ lib.mapAttrsToList (_: app: app.port) cfg.apps;
}
