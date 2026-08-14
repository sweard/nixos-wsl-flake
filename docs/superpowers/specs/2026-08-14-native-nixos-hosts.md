# Native NixOS Hosts Specification

## Goal

Extend the existing NixOS-WSL Flake with installable `x86_64-linux` configurations for a VMware UEFI guest and the Ryzen 9 7950X + RTX 4090 physical workstation.

## Architecture

- Keep one Git branch and one Flake because user, development, shell, Docker, desktop, and Nix settings are shared.
- Preserve hardware variability at the host seam with two adapters: `hosts/vmware` and `hosts/physical`.
- Preserve the existing `wsl` output and keep NixOS-WSL-only options out of shared modules.
- Expose three stable Flake interfaces: `nixosConfigurations.wsl`, `nixosConfigurations.vmware`, and `nixosConfigurations.physical`.

## Host contract

- All hosts use the `nixos` user, `x86_64-linux`, `Asia/Shanghai`, and state version `26.05`.
- Native hosts use UEFI with systemd-boot.
- Native installation media must label the ext4 root filesystem `nixos` and the FAT32 EFI system partition `boot`.
- Native hosts use NetworkManager, PipeWire, SDDM, and Plasma 6.
- VMware enables open-vm-tools through `virtualisation.vmware.guest.enable` and includes VMware storage/guest kernel modules.
- Physical enables AMD microcode/firmware, KVM for the Ryzen 9 7950X, and the open NVIDIA kernel module for the RTX 4090.
- The WSL-only FLClash loopback proxy remains scoped to WSL. Native hosts do not assume a proxy at `127.0.0.1:7890`.
- No secrets, password hashes, disk UUIDs, or machine-local credentials enter the repository.

## Verification contract

- Static checks: `git diff --check` and `bash -n scripts/doctor.sh`.
- Nix host checks: `nix flake check`, evaluate all three hostnames, and build each `config.system.build.toplevel`.
- No push is performed.
