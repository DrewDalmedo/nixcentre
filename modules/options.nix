# The knobs for this server. Set them in hosts/nixcentre/default.nix.
{ config, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.nixcentre;
in
{
  options.nixcentre = {
    adminUser = mkOption {
      type = types.str;
      description = "Your login on the server. Also the account for the shared folder.";
    };

    sshKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "SSH public keys allowed to log in as the admin user.";
    };

    domain = mkOption {
      type = types.str;
      default = "home.arpa";
      description = ''
        DNS domain of the home network. The homepage is at `nixcentre.<domain>`
        and each app gets `<app>.<domain>`.
      '';
    };

    lan = {
      subnet = mkOption {
        type = types.strMatching "[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}";
        default = "10.10.10";
        description = ''
          First three numbers of the home network's addresses. The server is `.1`
          and other devices get `.100` to `.250`.
        '';
      };

      ports = mkOption {
        type = types.listOf types.str;
        default = [ "en*" ];
        description = ''
          Wired network ports that make up the home network (shell globs).
          USB tethering devices are always excluded.
        '';
      };

      interface = mkOption {
        type = types.str;
        readOnly = true;
        default = "br0";
        description = "The bridge that joins the wired ports and the Wi-Fi hotspot into one network.";
      };

      address = mkOption {
        type = types.str;
        readOnly = true;
        default = "${cfg.lan.subnet}.1";
        defaultText = lib.literalExpression ''"''${config.nixcentre.lan.subnet}.1"'';
        description = "The server's address on the home network.";
      };

      cidr = mkOption {
        type = types.str;
        readOnly = true;
        default = "${cfg.lan.subnet}.0/24";
        defaultText = lib.literalExpression ''"''${config.nixcentre.lan.subnet}.0/24"'';
        description = "The home network in CIDR notation.";
      };
    };

    fakeInternet = mkEnableOption ''
      answering the "is there internet?" checks of phones, tablets and computers.
      Devices then stay on the home network happily and short names always work,
      but phones stop using mobile data while connected
    '';

    shareTetheredInternet = mkEnableOption ''
      sharing the internet connection of a USB-tethered phone with the whole home
      network. Everything on the network then uses your phone's data
    '';

    mediaDir = mkOption {
      type = types.str;
      default = "/srv/media";
      description = "Where movies, shows, books, audiobooks and Wikipedia files live.";
    };

    dataDisk = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "media";
      description = ''
        Filesystem label of an extra drive (internal or USB) to mount at
        {option}`nixcentre.mediaDir`. `null` keeps everything on the system drive.
      '';
    };

    wifi = {
      enable = mkEnableOption "a Wi-Fi hotspot on the ThinkCentre's own Wi-Fi card";

      interface = mkOption {
        type = types.str;
        example = "wlp1s0";
        description = "Name of the Wi-Fi interface, as shown by `ip link`.";
      };

      ssid = mkOption {
        type = types.str;
        default = "nixcentre";
        description = "Name of the Wi-Fi network.";
      };

      passwordFile = mkOption {
        type = types.str;
        default = "/var/lib/nixcentre/wifi-password";
        description = "File holding the Wi-Fi password (8 to 63 characters). Kept out of the Nix store.";
      };

      countryCode = mkOption {
        type = types.str;
        default = "US";
        description = "Two-letter country code, which decides the allowed Wi-Fi channels.";
      };

      channel = mkOption {
        type = types.ints.between 1 13;
        default = 6;
        description = "2.4 GHz channel to use.";
      };
    };

    apps = mkOption {
      internal = true;
      default = { };
      description = ''
        Web apps served on the home network. Each app module registers itself here;
        the homepage, the reverse proxy and the firewall are generated from this list.
      '';
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              title = mkOption { type = types.str; };
              description = mkOption { type = types.str; };
              icon = mkOption {
                type = types.str;
                description = "An emoji, so the homepage needs no image files.";
              };
              subdomain = mkOption {
                type = types.str;
                default = name;
              };
              port = mkOption { type = types.port; };
              order = mkOption {
                type = types.int;
                default = 100;
              };
            };
          }
        )
      );
    };
  };
}
