# Installing nixcentre

Budget about an hour. You need:

- the ThinkCentre, plus a monitor and keyboard for the install (afterwards it
  runs without them)
- a USB stick of 2 GB or more
- an Android phone with USB tethering and its cable, with about 2.4 GB of mobile
  data, or 1.3 GB if you do [step 6](#6-optional-save-about-1-gb-of-phone-data).
  For an iPhone, see the note in step 3.
- the NixOS installer, downloaded somewhere with internet

## 1. Make the installer USB stick

Download the minimal installer (1.8 GB) from
<https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso>.
The closer you install to the day you download it, the more of the system it can
supply itself (step 6).

Write it to the stick, which erases the stick. Use [balenaEtcher](https://etcher.balena.io),
or Rufus in "DD image" mode on Windows. On Linux or macOS:
`sudo dd if=nixos-minimal-….iso of=/dev/sdX bs=4M status=progress conv=fsync`.

## 2. BIOS settings

Switch the ThinkCentre on and press <kbd>F1</kbd> for setup. Names vary a little
between models:

- **Startup**: set *CSM* to *Disabled* and *Boot Mode* to *UEFI*.
- **Security**: set *Secure Boot* to *Disabled*.
- **Power**: set *After Power Loss* to *Power On*, so the server comes back by
  itself after a power cut.
- **Main**: check the date and time. If they are wrong after the machine has been
  unplugged, its CMOS battery (a CR2032 coin cell) is flat. Replace it, because the
  server keeps its own time while it's offline.

Save and exit with <kbd>F10</kbd>.

## 3. Boot the installer and get online

Plug in the USB stick, switch on, press <kbd>F12</kbd>, pick the USB stick, then
the first menu entry. You end up at a prompt as the user `nixos`.

Plug in your phone and turn on USB tethering. On Android that's
*Settings → Network & internet → Hotspot & tethering → USB tethering*. Check that
you're online:

```sh
ping -c 3 cache.nixos.org
```

> **iPhone:** USB tethering needs a helper program that the installer lacks.
> After the install it works fine, but for the install itself, use Personal
> Hotspot over Wi-Fi instead, if the ThinkCentre has a Wi-Fi card:
> `sudo nmcli device wifi connect "Your iPhone" password "hotspot password"`.
> Otherwise use any Ethernet connection with internet.

## 4. Partition the drive

Become root, then find the internal drive with `lsblk`. It's usually `nvme0n1`
(an M.2 SSD) or `sda` (a 2.5" drive). Leave the USB stick alone; it's the one
the size of your stick. **Everything on the drive you pick is erased.**

```sh
sudo -i
lsblk
DISK=/dev/nvme0n1      # or /dev/sda

wipefs -a $DISK
parted -s $DISK -- mklabel gpt \
  mkpart nixcentre-boot fat32 1MiB 1GiB set 1 esp on \
  mkpart nixcentre-root ext4 1GiB 100%
udevadm settle
mkfs.fat -F 32 -n BOOT /dev/disk/by-partlabel/nixcentre-boot
mkfs.ext4 -F -L nixos /dev/disk/by-partlabel/nixcentre-root

mount /dev/disk/by-label/nixos /mnt
mount --mkdir -o umask=077 /dev/disk/by-label/BOOT /mnt/boot
```

The labels `BOOT` and `nixos` are how the system finds its drives, so no
hardware file needs editing. With two drives, install on the SSD; the other one
can become the media drive later (see
[Storage](using.md#storage-and-adding-a-media-drive)).

## 5. Get this configuration

```sh
git clone https://github.com/DrewDalmedo/nixcentre /mnt/etc/nixos
cd /mnt/etc/nixos
```

If the repository is private, clone with a GitHub personal access token
(`https://YOUR-NAME:TOKEN@github.com/DrewDalmedo/nixcentre`), or copy the folder
over on a second USB stick.

## 6. Optional: save about 1 GB of phone data

The installer stick already holds a lot of what the system needs, including the
Linux kernel and the 850 MB of hardware firmware. The install copies them from
the stick instead of downloading, but only if the versions match exactly. This
pins the configuration to the installer's own NixOS version:

```sh
ver=$(nixos-version | cut -d' ' -f1)
nix --extra-experimental-features 'nix-command flakes' flake lock \
  --override-input nixpkgs "https://releases.nixos.org/nixos/26.05/nixos-$ver/nixexprs.tar.xz"
```

The next `nix flake update` moves back to the newest packages as usual.

## 7. Install

```sh
nixos-install --flake .#nixcentre
```

When it finishes, it asks for a root password. Then set the password for your
own account, give the configuration folder to it, and restart:

```sh
nixos-enter --root /mnt -c 'passwd drew'
nixos-enter --root /mnt -c 'chown -R drew:users /etc/nixos'
reboot
```

Pull out the USB stick while it restarts. Once it's up, you can unplug the phone.

## 8. First start

Log in as `drew` on the screen, or from a laptop on the home network with
`ssh drew@10.10.10.1`.

1. Set a password for the shared folder. It can differ from your login password:

   ```sh
   sudo smbpasswd -a drew
   ```

2. Connect the router or switch; see [The network](using.md#the-network).

3. On a phone or laptop on the home network, open <http://10.10.10.1> and set up
   each app once:

   - **Movies & TV (Jellyfin):** pick a language and create your account. Add a
     *Movies* library at `/srv/media/movies` and a *Shows* library at
     `/srv/media/shows`. Leave the remaining settings as they are.
   - **Books (Kavita):** create your account. Under *Server Settings →
     Libraries*, add a library of type *Book* on `/srv/media/books`. If you also
     have comics, see [Books](using.md#books-and-comics).
   - **Audiobooks (Audiobookshelf):** create the root account, then under
     *Settings → Libraries* add a library on `/srv/media/audiobooks`.
   - **Wikipedia (Kiwix):** nothing to do. It lists whatever is in the
     `wikipedia` folder.

4. While you still have mobile data, install the apps you want. The Jellyfin
   and Audiobookshelf apps are on Android and iOS, and Jellyfin is also on most
   TVs. A smart TV can join your phone's hotspot once to install it. See
   [Phones and TVs](using.md#phones-and-tvs).

Then start [adding content](using.md#adding-content).

## If something goes wrong

- The boot menu lists earlier versions of the system. Pick one to go back.
- `systemctl --failed` lists anything that didn't start, and
  `journalctl -u jellyfin` (or `kavita`, `audiobookshelf`, `kiwix-serve`,
  `dnsmasq`) shows that service's log.
- Can't reach <http://10.10.10.1>? Check the cable, and make sure the router's own
  DHCP server is off (see [The network](using.md#the-network)).
