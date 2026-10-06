# Where the media lives: /srv/media, with one folder per kind of content. You (over
# the shared folder) can write there, and every app can read it.
{ config, lib, ... }:
let
  cfg = config.nixcentre;
  folders = [
    "movies"
    "shows"
    "books"
    "audiobooks"
    "wikipedia"
  ];
in
{
  users.groups.media = { };

  # setgid folders: new files and folders stay in the media group.
  systemd.tmpfiles.settings."10-nixcentre-media" = {
    ${cfg.mediaDir}.d = {
      user = "root";
      group = "media";
      mode = "2775";
    };
  }
  // lib.genAttrs (map (folder: "${cfg.mediaDir}/${folder}") folders) (_: {
    d = {
      user = cfg.adminUser;
      group = "media";
      mode = "2775";
    };
  });

  # An extra drive for media, found by its label. `nofail` lets the server boot
  # without it; the apps and the shared folder wait for it (RequiresMountsFor), so
  # nothing gets written to the system drive by mistake.
  fileSystems.${cfg.mediaDir} = lib.mkIf (cfg.dataDisk != null) {
    device = "/dev/disk/by-label/${cfg.dataDisk}";
    fsType = "auto";
    options = [
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };
}
