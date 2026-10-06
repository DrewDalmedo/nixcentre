# Wikipedia and other offline references, from .zim files dropped into the
# wikipedia folder. Get them from https://library.kiwix.org.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcentre;
  port = 8080;
  zimDir = "${cfg.mediaDir}/wikipedia";
  library = "/var/lib/kiwix-library/library.xml";

  rebuildLibrary = pkgs.writeShellApplication {
    name = "kiwix-rebuild-library";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      findutils
      kiwix-tools
    ];
    text = builtins.readFile ./kiwix-rebuild-library.sh;
  };
in
{
  nixcentre.apps.wiki = {
    title = "Wikipedia";
    description = "Wikipedia and other offline references, searchable.";
    icon = "📖";
    inherit port;
    order = 10;
  };

  services.kiwix-serve = {
    enable = true;
    inherit port;
    libraryPath = library;
    extraArgs = [
      "--monitorLibrary"
      "--skipInvalid"
    ];
  };

  systemd.services.kiwix-serve = {
    wants = [ "kiwix-library.service" ];
    after = [ "kiwix-library.service" ];
    unitConfig.RequiresMountsFor = [ cfg.mediaDir ];
  };

  systemd.services.kiwix-library = {
    description = "Update the Kiwix library from ${zimDir}";
    unitConfig.RequiresMountsFor = [ cfg.mediaDir ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe rebuildLibrary} ${zimDir} ${library}";
      StateDirectory = "kiwix-library";
      StateDirectoryMode = "0755";
      # It only reads the ZIM folder and writes its own state directory.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateNetwork = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  # Rebuild when something in the folder changes (a copy finishing, a file being
  # deleted), and hourly in case a change slipped past.
  systemd.paths.kiwix-library = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = zimDir;
  };
  systemd.timers.kiwix-library = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "hourly";
  };
}
