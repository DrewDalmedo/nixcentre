# Settings for this server. Everything you are likely to want to change is here.
{
  imports = [
    ./hardware.nix

    # The server itself
    ../../modules/options.nix
    ../../modules/base.nix
    ../../modules/network.nix
    ../../modules/fake-internet.nix
    ../../modules/wifi-ap.nix
    ../../modules/storage.nix
    ../../modules/samba.nix
    ../../modules/web.nix

    # Apps. Delete a line to drop an app; the homepage and firewall follow along.
    ../../modules/kiwix.nix # Wikipedia and other offline references
    ../../modules/jellyfin.nix # Movies & TV
    ../../modules/books.nix # Ebooks, comics and audiobooks
  ];

  networking.hostName = "nixcentre";
  time.timeZone = "America/New_York";

  nixcentre = {
    adminUser = "drew";

    # SSH public keys that may log in as the admin user, e.g. the contents of
    # ~/.ssh/id_ed25519.pub on your laptop. Password logins work too.
    sshKeys = [ ];

    # false: phones keep using mobile data and show "no internet" on the home network.
    # true:  the server answers devices' internet checks, so they stay on the home
    #        network and short names always work, but phones stop using mobile data.
    fakeInternet = false;

    # Share a USB-tethered phone's internet with every device at home (uses phone data).
    shareTetheredInternet = false;

    # Label of an extra drive to keep media on, e.g. "media". null = the system drive.
    dataDisk = null;

    # The ThinkCentre's own Wi-Fi as a hotspot. See "Wi-Fi" in docs/using.md first.
    wifi = {
      enable = false;
      interface = "wlp1s0";
      ssid = "nixcentre";
    };
  };

  # The NixOS release this machine was installed with. Leave it alone when updating.
  system.stateVersion = "26.05";
}
