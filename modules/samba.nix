# The shared folder: \\nixcentre\media on Windows, smb://nixcentre.local/media on a
# Mac. Log in with the admin user and the password set with `sudo smbpasswd -a`.
{ config, ... }:
let
  cfg = config.nixcentre;
  lan = cfg.lan.interface;
in
{
  services.samba = {
    enable = true;
    # Discovery happens through wsdd (Windows) and Avahi (macOS) instead.
    nmbd.enable = false;
    winbindd.enable = false;
    settings = {
      global = {
        "server string" = config.networking.hostName;
        "hosts allow" = "${cfg.lan.cidr} 127.0.0.1";
        "load printers" = "no";
        "disable spoolss" = "yes";
        # Store macOS extras as file attributes, not as "._" files next to your media.
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:metadata" = "stream";
        "fruit:model" = "MacSamba";
        "fruit:posix_rename" = "yes";
        "fruit:veto_appledouble" = "no";
        "fruit:nfs_aces" = "no";
        "fruit:wipe_intentionally_left_blank_rfork" = "yes";
        "fruit:delete_empty_adfiles" = "yes";
      };
      media = {
        path = cfg.mediaDir;
        comment = "Movies, shows, books, audiobooks and Wikipedia";
        "read only" = "no";
        "valid users" = "@media";
        # Readable by every app, writable by you.
        "force group" = "media";
        "create mask" = "0664";
        "force create mode" = "0644";
        "directory mask" = "2775";
        "force directory mode" = "2755";
      };
    };
  };

  systemd.services.samba-smbd.unitConfig.RequiresMountsFor = [ cfg.mediaDir ];

  # Lets Windows list the server under "Network".
  services.samba-wsdd = {
    enable = true;
    interface = lan;
  };

  # Lets macOS Finder list the server under "Network".
  services.avahi.extraServiceFiles.smb = ''
    <?xml version="1.0" standalone='no'?>
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    <service-group>
      <name replace-wildcards="yes">%h</name>
      <service>
        <type>_smb._tcp</type>
        <port>445</port>
      </service>
    </service-group>
  '';

  networking.firewall.interfaces.${lan} = {
    allowedTCPPorts = [
      445 # SMB
      5357 # wsdd
    ];
    allowedUDPPorts = [ 3702 ]; # wsdd
  };
}
