{ lib, pkgs, ... }:
{
  # Fusion on Apple Silicon recommends NVMe storage and vmxnet3 networking.
  # SATA/SCSI modules remain available so the same host profile tolerates
  # different VMware virtual-disk controller choices.
  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "sd_mod"
    "sr_mod"
    "vmxnet3"
  ];

  boot.kernelModules =
    [ "vmxnet3" ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isx86 [
      "vmw_vmci"
      "vmw_vsock_vmci_transport"
    ];

  virtualisation.vmware.guest.enable = true;
}
