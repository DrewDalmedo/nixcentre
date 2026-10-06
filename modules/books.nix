# Ebooks and comics with Kavita, audiobooks and podcasts with Audiobookshelf.
{ config, ... }:
let
  cfg = config.nixcentre;
  kavitaToken = "/var/lib/nixcentre/kavita-token";
in
{
  nixcentre.apps.books = {
    title = "Books";
    description = "Ebooks and comics, read in the browser or on an e-reader.";
    icon = "📚";
    port = 5000;
    order = 30;
  };

  nixcentre.apps.audiobooks = {
    title = "Audiobooks";
    description = "Audiobooks and podcasts that remember where you stopped.";
    icon = "🎧";
    port = 8000;
    order = 40;
  };

  services.kavita = {
    enable = true;
    tokenKeyFile = kavitaToken;
    settings.Port = 5000;
  };

  # Kavita signs logins with a secret key; create it on first boot so it never
  # ends up in the repo or the Nix store.
  systemd.services.kavita-token = {
    description = "Create Kavita's secret key";
    requiredBy = [ "kavita.service" ];
    before = [ "kavita.service" ];
    unitConfig.ConditionPathExists = "!${kavitaToken}";
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
    };
    script = ''
      mkdir -p "$(dirname ${kavitaToken})"
      head -c 64 /dev/urandom | base64 --wrap=0 > ${kavitaToken}.new
      mv ${kavitaToken}.new ${kavitaToken}
    '';
  };

  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0";
    port = 8000;
  };

  users.users.kavita.extraGroups = [ "media" ];
  users.users.audiobookshelf.extraGroups = [ "media" ];

  systemd.services.kavita.unitConfig.RequiresMountsFor = [ cfg.mediaDir ];
  systemd.services.audiobookshelf.unitConfig.RequiresMountsFor = [ cfg.mediaDir ];
}
