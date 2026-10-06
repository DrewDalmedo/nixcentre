# The ThinkCentre's own Wi-Fi card as a hotspot, joined to the home network bridge.
# Off by default; see "Wi-Fi" in docs/using.md for checking that your card can do it.
{ config, lib, ... }:
let
  cfg = config.nixcentre;
  inherit (cfg) wifi;
  lan = cfg.lan.interface;
in
{
  config = lib.mkMerge [
    {
      # Keep hostapd on disk even while the hotspot is off, so switching it on
      # doesn't need an internet connection.
      system.extraDependencies = [ config.services.hostapd.package ];
    }

    (lib.mkIf wifi.enable {
      services.hostapd = {
        enable = true;
        radios.${wifi.interface} = {
          band = "2g";
          inherit (wifi) channel countryCode;
          # 20 MHz only: Intel cards often refuse wider channels in hotspot mode, and
          # wide channels on 2.4 GHz mostly add interference in an apartment anyway.
          wifi4.capabilities = [ "SHORT-GI-20" ];
          networks.${wifi.interface} = {
            inherit (wifi) ssid;
            authentication = {
              # Plain WPA2: works with every phone, laptop, TV and e-reader.
              mode = "wpa2-sha1";
              wpaPasswordFile = wifi.passwordFile;
            };
            settings.bridge = lan;
          };
        };
      };

      systemd.services.hostapd = {
        wants = [ "sys-subsystem-net-devices-${lan}.device" ];
        after = [ "sys-subsystem-net-devices-${lan}.device" ];
      };
    })
  ];
}
