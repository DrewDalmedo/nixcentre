# The basics: boot, your user account, SSH, time, graphics drivers, and Nix
# settings that keep working when there's no internet.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcentre;
in
{
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.${cfg.adminUser} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "media"
    ];
    openssh.authorizedKeys.keys = cfg.sshKeys;
  };

  # Only reachable from the home network (see network.nix).
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };
  };

  # Video decoding/encoding on the Intel GPU, for Jellyfin. intel-media-driver
  # covers Broadwell (5th gen) and newer, intel-vaapi-driver older chips; libva
  # picks the right one. Check with `vainfo`.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
    ];
  };

  # Keeps time from the internet while a phone is tethered, otherwise from the
  # ThinkCentre's own clock, and hands the time out to devices on the home network.
  services.chrony = {
    enable = true;
    # Always jump to the right time after being offline for a while, rather than
    # creeping towards it (the default only allows jumps in the first few updates).
    makestep.enable = false;
    extraConfig = ''
      makestep 1 -1
      allow ${cfg.lan.cidr}
      local stratum 10
    '';
  };

  nix = {
    # Flakes only; nixpkgs comes from flake.lock and stays pinned in the registry,
    # so it's never garbage-collected and never needs downloading again.
    channel.enable = false;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Keep what was needed to build this system, so changing a setting and
      # rebuilding works with no internet.
      keep-outputs = true;
      keep-derivations = true;
      connect-timeout = 5;
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Works offline: suggests which package provides a missing command.
  programs.command-not-found.dbPath = lib.mkIf (
    config.nixpkgs.flake.source != null
  ) "${config.nixpkgs.flake.source}/programs.sqlite";

  zramSwap.enable = true;
  services.fstrim.enable = true;

  environment.systemPackages = with pkgs; [
    git
    htop
    iw
    libva-utils
    ncdu
    pciutils
    usbutils
  ];
}
