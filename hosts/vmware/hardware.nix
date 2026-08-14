{ ... }:
{
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "ahci"
    "sd_mod"
    "sr_mod"
  ];

  boot.kernelModules = [
    "vmw_vmci"
    "vmw_vsock_vmci_transport"
    "vmxnet3"
  ];

  virtualisation.vmware.guest.enable = true;
}
