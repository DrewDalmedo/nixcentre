# Movies & TV with Jellyfin. Apps for phones, tablets and most TVs find the
# server by themselves on the home network.
{ config, ... }:
let
  cfg = config.nixcentre;
in
{
  nixcentre.apps.tv = {
    title = "Movies & TV";
    description = "Your films and shows, on any screen. Jellyfin apps work too.";
    icon = "🎬";
    port = 8096;
    order = 20;
  };

  services.jellyfin = {
    enable = true;
    # Let the Intel GPU do video conversion for devices that can't play a file as-is.
    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
      device = "/dev/dri/renderD128";
    };
    # Starting values only: afterwards change them in Jellyfin under Dashboard >
    # Playback > Transcoding. These codecs work on every Intel chip since 2013; run
    # `vainfo` to see what else yours can do (HEVC and VP9 on most Tiny models).
    transcoding = {
      enableHardwareEncoding = true;
      enableToneMapping = false;
      hardwareDecodingCodecs = {
        h264 = true;
        mpeg2 = true;
        vc1 = true;
      };
    };
  };

  users.users.jellyfin.extraGroups = [
    "media"
    "render"
    "video"
  ];

  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ cfg.mediaDir ];

  # Lets Jellyfin apps discover the server.
  networking.firewall.interfaces.${cfg.lan.interface}.allowedUDPPorts = [ 7359 ];
}
