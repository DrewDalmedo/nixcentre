# Using nixcentre

- [The network](#the-network)
- [Phones and TVs](#phones-and-tvs)
- [Adding content](#adding-content)
- [Using the phone's internet](#using-the-phones-internet)
- [Updating and changing settings](#updating-and-changing-settings)
- [Storage and adding a media drive](#storage-and-adding-a-media-drive)
- [Troubleshooting](#troubleshooting)

## The network

The ThinkCentre runs the home network at `10.10.10.1`. It gives every device an
address (`10.10.10.100` to `.250`) and answers names like `tv.home.arpa`. Pick
one of these ways to connect devices.

### A spare Wi-Fi router (recommended)

Use the router only for its Wi-Fi:

1. Set it up following its manual: choose the Wi-Fi name and password.
2. Switch it to **access point mode** if it has one. If it doesn't, **turn off
   its DHCP server**. Two DHCP servers on one network will hand out the wrong
   addresses.
3. If it asks for an address of its own, give it `10.10.10.2`, netmask
   `255.255.255.0`, gateway `10.10.10.1`.
4. Connect one of its **LAN** ports (not the WAN or Internet port) to the
   ThinkCentre.

Using the router in normal mode, with the ThinkCentre on its WAN port, also
works. Your devices then sit on the router's own network behind it, though.
`http://10.10.10.1` and the app addresses still work, but `nixcentre.local`,
Jellyfin apps finding the server by themselves, and Windows or Macs listing the
shared folder don't.

### A switch or a single cable

Plug in and go. Devices get their addresses automatically.

### The ThinkCentre's own Wi-Fi

The ThinkCentre can be the hotspot itself, as long as its Wi-Fi card supports
it:

1. Check the card. `iw list | grep -A 8 'Supported interface modes'` must list
   `AP`, and `ip link` shows the card's name, e.g. `wlp1s0`. Intel cards (the
   usual ones in a ThinkCentre) only do it on 2.4 GHz. That's enough for one or
   two HD streams. No card, or it can't? A USB Wi-Fi adapter with a MediaTek
   MT7612U or MT7921AU chip works well.
2. Choose a password of at least 8 characters:

   ```sh
   sudo mkdir -p /var/lib/nixcentre
   echo 'your wifi password' | sudo tee /var/lib/nixcentre/wifi-password > /dev/null
   sudo chmod 600 /var/lib/nixcentre/wifi-password
   ```

3. In `hosts/nixcentre/default.nix`, set `wifi.enable = true;` and set
   `wifi.interface` to your card's name. You can also change `ssid`, and
   `countryCode` if you're not in the US. Then
   [rebuild](#updating-and-changing-settings). This works offline.

The Ethernet port stays part of the same network, so you can mix both.

## Phones and TVs

**Bookmark <http://10.10.10.1>** or add it to your home screen. It works however
your phone is set up.

### Phones and mobile data

Out of the box (`fakeInternet = false`), phones see that the home network has no
internet. They show "No internet" or "Connected without internet" and keep using
mobile data for everything else. Messages and notifications keep arriving.

The catch is that a phone with mobile data on may send your requests for home
pages over mobile data, where they go nowhere. Android in particular does this.
If a home page won't load:

- turn mobile data off from the quick settings while you watch or read, and back
  on afterwards; or
- if Android asks whether to stay connected to a network without internet,
  answer yes. It then stays on the home Wi-Fi and stops using mobile data while
  connected.

If you'd rather every device always treat the home network as online, set
`fakeInternet = true` and [rebuild](#updating-and-changing-settings). The server
then answers the "is there internet?" checks of Android, iOS, Windows, macOS,
Firefox and Linux. Short names like `wiki.home.arpa` then always work, but
phones stop using mobile data while connected. To get online, you switch Wi-Fi
off. Newer Android versions may still ask once whether to keep using a network
with "limited connectivity"; say yes.

### Apps

Install these while you have internet. Smart TVs can join your phone's hotspot
once to do it.

| Service | Apps | Server address to enter |
| --- | --- | --- |
| Movies & TV | Jellyfin for Android, iOS, Android/Google TV, Fire TV, Roku, LG, Samsung; Swiftfin for Apple TV | `http://10.10.10.1:8096` (most apps find it by themselves) |
| Audiobooks | Audiobookshelf for Android and iOS | `http://10.10.10.1:8000` |
| Books | Any OPDS reader app, such as KOReader or Moon+ Reader. Kavita shows your OPDS link under your account settings. | the OPDS link |
| Wikipedia | The browser | `http://10.10.10.1:8080` |

## Adding content

Open the shared folder and drop files into the right subfolder:

- **Windows:** in File Explorer's address bar, type `\\nixcentre\media`, or
  `\\10.10.10.1\media`. Right-click it to *Map network drive* for next time.
- **Mac:** in Finder, use *Go → Connect to Server* with
  `smb://nixcentre.local/media`, or `smb://10.10.10.1/media`.
- **Linux:** use `smb://10.10.10.1/media` in the file manager.

Log in as `drew` with the password from `sudo smbpasswd -a drew`. Big copies go
much faster over a cable than over Wi-Fi.

### Movies and shows

Jellyfin recognises films and episodes from their names:

```
movies/
  Arrival (2016)/
    Arrival (2016).mkv
    Arrival (2016).en.srt            subtitles, optional
shows/
  The Expanse/
    Season 01/
      The Expanse S01E01.mkv
      The Expanse S01E02.mkv
```

New files show up within a few minutes, or straight away with *Scan All
Libraries* in Jellyfin's Dashboard.

### Books and comics

Kavita wants one folder per series. A standalone book counts as a series of
one:

```
books/
  Terry Pratchett/
    Guards! Guards!.epub
  The Expanse/
    Leviathan Wakes.epub
```

If you have comics or manga as well, keep them apart, because Kavita libraries
can't overlap. Use `books/Ebooks` and `books/Comics`, and give each its own
library in Kavita (types *Book* and *Comic*).

### Audiobooks

One folder per book, inside a folder per author:

```
audiobooks/
  Andy Weir/
    Project Hail Mary/
      Project Hail Mary.m4b          or a folder of numbered .mp3 files
```

### Wikipedia and other references

Kiwix serves `.zim` files: whole websites packed into one file. Get them from
<https://library.kiwix.org>, which shows the size of each. Use the torrent link
for big ones. For English Wikipedia, roughly:

| File name starts with | Contents | Size |
| --- | --- | --- |
| `wikipedia_en_all_maxi` | every article, with pictures | about 110 GB |
| `wikipedia_en_all_nopic` | every article, no pictures | about 50 GB |
| `wikipedia_en_all_mini` | the start of every article | about 12 GB |

Also worth a look: Wiktionary, Wikivoyage (travel), Project Gutenberg (free
classic books), iFixit (repair guides), WikiHow, and Stack Exchange sites such as
Cooking or Ask Ubuntu.

Drop the file straight into the `wikipedia` folder. It shows up within a minute
of the copy finishing; files still being copied are skipped until they're
complete. To replace an old version, delete the old file.

### Posters and descriptions

Jellyfin fetches posters, plot summaries and cast lists from the internet, so
new films show up as plain file names until it can. Two ways to fill them in:

- **Connect the server to your phone** (below), then in Jellyfin choose
  *Dashboard → Libraries → Scan All Libraries*. It costs a few MB per film.
- **Bring them with the files.** [tinyMediaManager](https://www.tinymediamanager.org),
  running on a laptop that has internet, saves a poster and an `.nfo` file next
  to each video. Jellyfin reads those offline.

Audiobookshelf can do the same with *Match* on a book while the phone is
connected. Book covers and details embedded in the files work offline.

## Using the phone's internet

The server gets online through your phone, over a USB cable or the phone's Wi-Fi
hotspot. Either way, `networkctl` shows the connection once it's up.

### iPhone over USB

1. Turn on *Settings → Personal Hotspot → Allow Others to Join*.
2. Plug the iPhone into the ThinkCentre and unlock it.
3. The first time, tap *Trust* and enter your passcode.

The server is online within seconds, and the iPhone charges while it's plugged
in. Unplug it when you're done.

### Android over USB

Plug it in and turn on
*Settings → Network & internet → Hotspot & tethering → USB tethering*.

### Over the phone's Wi-Fi hotspot

This uses the ThinkCentre's Wi-Fi card, so it isn't available while the card is
the home network's own hotspot (`wifi.enable = true`). Use USB then.

The curly apostrophe in iPhone names (*Sam’s iPhone*) is hard to type, so
first rename the phone to something simple, like `iphone`, under
*Settings → General → About → Name*.

Turn on the hotspot. Then on the server, find the card's name and join the
hotspot. You only need to enter the password the first time:

```sh
iwctl device list                          # the card's name, e.g. wlp1s0
iwctl station wlp1s0 get-networks          # your phone should be listed
iwctl station wlp1s0 connect iphone        # asks for the hotspot password
```

The server remembers the hotspot and rejoins whenever it's on. If you also turn
on the hotspot for other things, stop it from rejoining by itself so it
doesn't use data behind your back:

```sh
iwctl known-networks iphone set-property AutoConnect no
```

Then connect by hand when you want to, and `iwctl station wlp1s0 disconnect`
when you're done.

### Sharing it with the home network

Only the server uses this connection. To share it with everything at home, set
`shareTetheredInternet = true` and rebuild. Then every device on your network
uses your phone's data, which goes fast with TVs and laptops around.

## Updating and changing settings

The configuration lives in `/etc/nixos`, which is a copy of this repository.

**To change a setting** (this works without internet):

```sh
cd /etc/nixos
nano hosts/nixcentre/default.nix
sudo nixos-rebuild switch --option substitute false
```

Without internet, `--option substitute false` stops it from trying to download
anything. Settings changes don't need downloads, but adding new apps or
packages does. Note your changes with `git commit -am "What I changed"`, and
`git push` them next time you're online.

**To update the software**, [connect the server to your phone](#using-the-phones-internet)
and run:

```sh
cd /etc/nixos
nix flake update
sudo nixos-rebuild switch
git commit -am "Update" && git push
```

An update downloads everything that changed since the last one: from about
100 MB to 2 GB, depending on how long it's been. The server never talks to the
internet otherwise, so updating every few months is plenty. Once a year, NixOS
has a new release (26.11, 27.05, ...). To move to it, change `nixos-26.05` in
`flake.nix` and read the release notes first. Leave `system.stateVersion` alone.

**To undo** a change or update, run `sudo nixos-rebuild switch --rollback`, or
pick an older entry in the boot menu. Versions older than 30 days are cleaned
up weekly.

## Storage and adding a media drive

`df -h /srv/media` shows how much space is left. To move your media to a
bigger drive, internal or USB:

1. Find the new drive with `lsblk`, then format it. This **erases it**. Use ext4,
   because exFAT and NTFS can't store the permissions the apps need.

   ```sh
   sudo mkfs.ext4 -L media /dev/sdX
   ```

2. Move your media across:

   ```sh
   sudo systemctl stop samba-smbd jellyfin kavita audiobookshelf kiwix-serve
   sudo mount /dev/disk/by-label/media /mnt
   sudo rsync -a --remove-source-files /srv/media/ /mnt/
   sudo umount /mnt
   ```

3. Set `dataDisk = "media";` in `hosts/nixcentre/default.nix`, rebuild, and
   restart.

If that drive is ever missing, the server still starts. The apps and shared
folder wait for the drive rather than filling up the system drive.

## Troubleshooting

- **A phone shows "No internet" and home pages don't load:** turn off mobile
  data, or use the `10.10.10.1` addresses. See [Phones and TVs](#phones-and-tvs).
- **Devices get addresses like `192.168.x.x`:** the router's own DHCP server is
  still on.
- **A Wikipedia file doesn't appear:** make sure the copy finished and the name
  ends in `.zim`. `journalctl -u kiwix-library` lists skipped files.
- **Videos stutter:** the server is probably converting them for your device.
  Run `vainfo` to see which formats the GPU can handle, then enable them in
  Jellyfin under *Dashboard → Playback → Transcoding*. Most Tiny models handle
  HEVC, and 7th-generation and newer also handle HEVC 10-bit and VP9.
- **Something isn't running:** `systemctl --failed`, then `journalctl -b -u NAME`
  for its log.
- **The clock is wrong:** `chronyc tracking` shows the time source. Connecting a
  phone corrects it. If the clock resets whenever the server loses power,
  replace its CMOS battery.
