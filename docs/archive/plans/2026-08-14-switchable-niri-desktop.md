# Plasma and Niri Switchable Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Plasma 6 and add a complete Niri Wayland session selectable from SDDM on native NixOS hosts.

**Architecture:** `native-workstation.nix` remains the native host interface and imports one focused `native-desktop.nix` implementation. That desktop module owns the shared display manager, sessions, audio, networking, Niri support packages, and Niri-only user services; host adapters and WSL remain unchanged.

**Tech Stack:** NixOS 26.05 modules, Plasma 6, Niri 26.04, SDDM/KWin Wayland, PipeWire/WirePlumber, NetworkManager, systemd user services.

**Spec:** `docs/superpowers/specs/2026-08-14-switchable-niri-desktop.md`

## Global Constraints

- Preserve the current Plasma 6 session and keep `plasma` as the default.
- Add Niri only to VMware and physical hosts; WSL must remain desktop-free.
- Use the Niri package and module from the locked Nixpkgs 26.05 input.
- Do not create another Git branch, commit, or push in this task.

---

### Task 1: Define the native desktop module

**Files:**
- Create: `modules/nixos/native-desktop.nix`
- Modify: `modules/nixos/native-workstation.nix`

**Interfaces:**
- Consumes: NixOS `pkgs`, `programs.niri`, display-manager, PipeWire, NetworkManager, and systemd user-service options.
- Produces: one native desktop stack imported only by `native-workstation.nix`, exposing SDDM sessions named `plasma` and `niri`.

- [x] **Step 1: Write the failing structural test**

Create a temporary assertion script that requires `native-workstation.nix` to import `native-desktop.nix` and requires that module to enable Plasma, Niri, SDDM Wayland, PipeWire, NetworkManager, and the Niri support packages.

- [x] **Step 2: Run the structural test to verify it fails**

Run the assertion script against the unchanged branch. Expected: failure because `modules/nixos/native-desktop.nix` does not exist.

- [x] **Step 3: Write the minimal desktop module**

Move the existing Plasma, SDDM, PipeWire, NetworkManager, rtkit, dconf and graphics settings into `native-desktop.nix`. Enable `programs.niri`, install `alacritty`, `fuzzel`, `waybar`, `swaylock`, `mako`, `xwayland-satellite`, `networkmanagerapplet`, `wl-clipboard`, `playerctl`, and `brightnessctl`, then bind Mako and the KDE Polkit agent to `niri.service`.

- [x] **Step 4: Re-run the structural test**

Expected: every assertion passes and the WSL host still has no import path to `native-desktop.nix`.

### Task 2: Document session switching and operations

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: SDDM session names and the upstream default Niri shortcuts.
- Produces: installation-independent instructions for choosing Plasma or Niri and customizing Niri.

- [x] **Step 1: Extend the failing documentation assertions**

Require the README to mention the SDDM session menu, Plasma, Niri, `Super+T`, `Super+D`, `Super+Alt+L`, and `~/.config/niri/config.kdl`.

- [x] **Step 2: Run the assertions to verify the documentation checks fail**

Expected: failure because the README currently documents only Plasma 6.

- [x] **Step 3: Add the operating guide**

Describe SDDM as the session switcher, keep Plasma as default, list Niri's essential shortcuts, explain the first-login generated config, and note the VMware 3D acceleration requirement.

- [x] **Step 4: Re-run the documentation assertions**

Expected: all documentation assertions pass.

### Task 3: Verify the complete change

**Files:**
- Verify: all changed `.nix`, Markdown, and shell-test inputs.

**Interfaces:**
- Consumes: the locked Nixpkgs module definitions and repository diff.
- Produces: evidence that syntax, option names, host isolation, and documentation match the specification.

- [x] **Step 1: Parse every Nix file**

Run the existing Tree-sitter Nix parser over all `.nix` files. Expected: zero parse errors.

- [x] **Step 2: Run repository checks**

Run the structural assertions, `git diff --check`, and shell syntax checks. Expected: exit status 0 for each command.

- [x] **Step 3: Confirm option provenance**

Compare `programs.niri`, SDDM Wayland, Plasma session, PipeWire, and NetworkManager options with the exact locked Nixpkgs 26.05 source.

- [x] **Step 4: Review the final diff against the spec**

Confirm Plasma remains enabled/default, Niri is native-only, the Niri session support is complete, README instructions are accurate, and no unrelated files changed.
