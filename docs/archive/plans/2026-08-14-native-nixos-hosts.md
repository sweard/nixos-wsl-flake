# Native NixOS Hosts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add VMware and Ryzen 9 7950X + RTX 4090 physical NixOS configurations without duplicating the existing workstation stack or breaking WSL.

**Architecture:** A `mkSystem` constructor in `flake.nix` is the small external interface for all hosts. `native-workstation.nix` hides the shared native workstation implementation, while VMware and physical hardware files are adapters at the hardware seam.

**Tech Stack:** Nix Flakes, NixOS 26.05 modules, Home Manager 26.05, NixOS-WSL, Plasma 6, open-vm-tools, NVIDIA open kernel modules.

**Spec:** `docs/superpowers/specs/2026-08-14-native-nixos-hosts.md`

## Global Constraints

- Preserve the existing `nixosConfigurations.wsl` interface.
- Add `nixosConfigurations.vmware` and `nixosConfigurations.physical`.
- Use one branch with separate hardware adapters.
- Use UEFI, root label `nixos`, and EFI label `boot` for native hosts.
- Keep the WSL proxy and NixOS-WSL options out of native configurations.
- Do not add secrets or push commits.

---

### Task 1: Shared host constructor and portable modules

**Files:**
- Modify: `flake.nix`
- Create: `modules/nixos/home-manager.nix`
- Create: `modules/nixos/native-workstation.nix`
- Modify: `modules/nixos/docker.nix`
- Modify: `modules/nixos/wsl.nix`
- Modify: `modules/nixos/base.nix`
- Modify: `hosts/wsl/default.nix`

**Interfaces:**
- Consumes: `inputs`, per-host `hostName`, and a list of NixOS modules.
- Produces: `mkSystem { hostName; modules; }`, a portable Docker module, and a shared native workstation module.

- [ ] **Step 1: Confirm the new Flake outputs do not exist**

Run on a Nix host:

```bash
nix eval .#nixosConfigurations.vmware.config.networking.hostName
nix eval .#nixosConfigurations.physical.config.networking.hostName
```

Expected before implementation: both commands fail because the attributes are missing.

- [ ] **Step 2: Add the `mkSystem` constructor**

Refactor `flake.nix` so every host receives:

```nix
userSettings = commonUserSettings // { inherit hostName; };
```

and the same Home Manager module plus Rust overlay.

- [ ] **Step 3: Extract shared Home Manager integration**

Create `modules/nixos/home-manager.nix` with the existing `useGlobalPkgs`, `useUserPackages`, backup extension, extra special arguments, and per-user import.

- [ ] **Step 4: Make Docker portable**

Move `wsl.docker-desktop.enable = false` from `docker.nix` into `wsl.nix`; keep native Docker and group membership shared.

- [ ] **Step 5: Add the native workstation module**

Create a module that imports base, Docker, and Home Manager; declares labelled ext4/FAT filesystems; enables systemd-boot, NetworkManager, PipeWire, SDDM, Plasma 6, dconf, fonts, and native diagnostic packages.

- [ ] **Step 6: Preserve WSL composition**

Make `hosts/wsl/default.nix` import the extracted Home Manager module while retaining WSL, WSLg, Docker, and proxy adapters.

### Task 2: VMware and physical hardware adapters

**Files:**
- Create: `hosts/vmware/default.nix`
- Create: `hosts/vmware/hardware.nix`
- Create: `hosts/physical/default.nix`
- Create: `hosts/physical/hardware.nix`
- Modify: `flake.nix`

**Interfaces:**
- Consumes: `modules/nixos/native-workstation.nix` and `userSettings` from `mkSystem`.
- Produces: buildable `vmware` and `physical` NixOS configurations.

- [ ] **Step 1: Add the VMware adapter**

Import the native workstation module, enable `virtualisation.vmware.guest.enable`, and include `vmw_pvscsi`, `vmw_vmci`, `vmxnet3`, SCSI/SATA, and optical-drive modules needed by common VMware virtual hardware.

- [ ] **Step 2: Add the physical adapter**

Import the native workstation module, enable redistributable firmware, AMD microcode, `kvm-amd`, NVIDIA X/Wayland integration, modesetting, and `hardware.nvidia.open = true` for the RTX 4090.

- [ ] **Step 3: Register both Flake outputs**

Add:

```nix
nixosConfigurations.vmware = mkSystem {
  hostName = "nixos-vmware";
  modules = [ ./hosts/vmware ];
};

nixosConfigurations.physical = mkSystem {
  hostName = "nixos-physical";
  modules = [ ./hosts/physical ];
};
```

### Task 3: Documentation and verification

**Files:**
- Modify: `README.md`
- Modify: `scripts/doctor.sh`

**Interfaces:**
- Consumes: Flake output names and the native disk-label contract.
- Produces: installation, rebuild, verification, and hardware-specific operating instructions.

- [ ] **Step 1: Generalize diagnostics**

Keep WSL environment output, add `systemd-detect-virt`, hostname, desktop session, renderer, NVIDIA, VMware tools, and service checks without making WSL variables mandatory on native hosts.

- [ ] **Step 2: Document the three outputs**

Add an output table and native installation sections covering VMware UEFI settings, physical NVIDIA behavior, ext4/FAT partition labels, `nixos-install --flake .#vmware`, `nixos-install --flake .#physical`, and post-install password setup.

- [ ] **Step 3: Run available local checks**

```bash
git diff --check
bash -n scripts/doctor.sh
```

Expected: exit status 0 with no output.

- [ ] **Step 4: Run Nix checks on NixOS**

```bash
nix flake check
nix eval --raw .#nixosConfigurations.wsl.config.networking.hostName
nix eval --raw .#nixosConfigurations.vmware.config.networking.hostName
nix eval --raw .#nixosConfigurations.physical.config.networking.hostName
nix build --dry-run .#nixosConfigurations.wsl.config.system.build.toplevel
nix build --dry-run .#nixosConfigurations.vmware.config.system.build.toplevel
nix build --dry-run .#nixosConfigurations.physical.config.system.build.toplevel
```

Expected hostnames: `nixos-wsl`, `nixos-vmware`, and `nixos-physical`; every command exits 0.

- [ ] **Step 5: Commit locally**

```bash
git add flake.nix hosts modules home scripts README.md docs
git commit -m "feat: add VMware and physical NixOS hosts"
```

Do not push.
