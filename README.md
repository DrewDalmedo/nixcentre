# nixcentre

A NixOS setup that turns an old Lenovo ThinkCentre Tiny into an offline home
server. Once it's set up, it needs no internet at all.

| What | Open in a browser | Address for apps (works without DNS) |
| --- | --- | --- |
| Homepage | <http://10.10.10.1>, <http://nixcentre.home.arpa>, <http://nixcentre.local> | |
| Wikipedia and other references (Kiwix) | <http://wiki.home.arpa> | `10.10.10.1:8080` |
| Movies & TV (Jellyfin) | <http://tv.home.arpa> | `10.10.10.1:8096` |
| Ebooks & comics (Kavita) | <http://books.home.arpa> | `10.10.10.1:5000` |
| Audiobooks & podcasts (Audiobookshelf) | <http://audiobooks.home.arpa> | `10.10.10.1:8000` |
| Shared folder for adding files | `\\nixcentre\media` (Windows), `smb://nixcentre.local/media` (Mac) | |

```
 phones, laptop, TV ))) Wi-Fi router in AP mode ──┐
                                                  ├── Ethernet ── ThinkCentre (10.10.10.1)
 or: laptop ───────────────── Ethernet switch ────┘                      │
                                                                         └── phone, over USB or
                                                                             its Wi-Fi hotspot
                                                                             (only for updates)
```

- The ThinkCentre runs the network. It hands out addresses (DHCP) and names
  (DNS), so a spare router only needs to provide Wi-Fi. The ThinkCentre's own
  Wi-Fi card can also act as a hotspot.
- Its internet connection is your phone: an iPhone or Android phone over USB,
  or the phone's Wi-Fi hotspot. You only need it for installing, updating, and
  fetching posters and descriptions for movies.
- Phones keep using mobile data while on the home network. One setting
  (`fakeInternet`) makes them treat the network as online instead.

## Documentation

- [docs/install.md](docs/install.md): installing, step by step, over your
  phone's hotspot. About 2.4 GB goes over the phone, or about half that with
  the optional data-saving step.
- [docs/using.md](docs/using.md): setting up the network, adding movies, books
  and Wikipedia, phones, updating, and troubleshooting.

## Settings

Everything you're likely to change is in
[`hosts/nixcentre/default.nix`](hosts/nixcentre/default.nix):

| Setting | Default | What it does |
| --- | --- | --- |
| `adminUser` | `"drew"` | Your login, also used for the shared folder |
| `sshKeys` | `[ ]` | SSH public keys allowed to log in |
| `fakeInternet` | `false` | Answer devices' internet checks so they stay on Wi-Fi. Phones then stop using mobile data while connected. |
| `shareTetheredInternet` | `false` | Share the phone's internet with every device at home |
| `dataDisk` | `null` | Label of an extra drive to keep media on, e.g. `"media"` |
| `wifi.enable` | `false` | Use the ThinkCentre's Wi-Fi card as a hotspot |
| `domain` | `"home.arpa"` | Names are `<app>.home.arpa` |
| `lan.subnet` | `"10.10.10"` | The server is `.1`; devices get `.100` to `.250` |

After changing something, run `sudo nixos-rebuild switch`. That works offline too,
see [Updating](docs/using.md#updating-and-changing-settings).

## Layout

```
flake.nix               nixpkgs pinned to the NixOS 26.05 channel
hosts/nixcentre/        this machine: settings and hardware
modules/
  options.nix           the settings above
  base.nix              boot, users, SSH, time, GPU drivers, offline-friendly Nix
  network.nix           the home network (bridge, DHCP/DNS, mDNS) and the phone
                        connection (USB tethering, Wi-Fi hotspot)
  fake-internet.nix     answers for devices' internet checks (when enabled)
  wifi-ap.nix           the Wi-Fi hotspot (when enabled)
  storage.nix           /srv/media and the optional media drive
  samba.nix             the shared folder
  web.nix, homepage.nix the homepage and app names
  kiwix.nix             Wikipedia (rescans the folder whenever files change)
  jellyfin.nix          movies & TV
  books.nix             Kavita and Audiobookshelf
tests/vm.nix            end-to-end test in virtual machines
```

Each app module registers itself in `nixcentre.apps`, and the homepage, app
names and firewall are generated from that list. Removing an app's line from
`hosts/nixcentre/default.nix` removes it everywhere.

## Testing

`nix flake check` builds everything and runs two tests in virtual machines.

[tests/vm.nix](tests/vm.nix) boots the server next to a simulated laptop and
checks:

- DHCP and DNS
- the homepage
- every app, by name and by port
- a Wikipedia file dropped into the folder
- the shared folder
- both `fakeInternet` modes

[tests/wifi.nix](tests/wifi.nix) uses simulated Wi-Fi radios to check:

- joining a phone's hotspot with `iwctl`, while keeping the apps closed to
  the phone's network
- broadcasting the home network for a laptop to join

They need KVM to run at a reasonable speed, and they download QEMU and the test
tools, so don't run them over phone data.
