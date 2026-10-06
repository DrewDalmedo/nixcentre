# Hardware settings for a Lenovo ThinkCentre Tiny (M700q to M90q).
#
# This stands in for the usual generated hardware-configuration.nix: the disks are
# found by their labels (set during install, see docs/install.md) and the boot
# modules cover NVMe, SATA and USB drives, so it works on any of these machines
# without editing. If you partitioned differently, replace this file with the output
# of `nixos-generate-config --show-hardware-config`.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "uas"
    "sd_mod"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
