#!/usr/bin/env bash
set -euo pipefail

# These are structural checks only; physical-workstation.nix checks evaluated
# option values when scripts/check.sh runs in an environment with Nix.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=${PHYSICAL_WORKSTATION_REPO:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
cd "$REPO_ROOT"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

active_text() {
  sed -E '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' "$@"
}

require_text() {
  local path=$1 text=$2
  active_text "$path" | rg -F --quiet -- "$text" || fail "missing $text in $path"
}

command -v rg >/dev/null 2>&1 || fail 'ripgrep is required'

host=hosts/physical/default.nix
hardware=hosts/physical/hardware.nix
proxy=modules/nixos/native-proxy.nix

for path in "$host" "$hardware" "$proxy" tests/physical-workstation.nix docs/physical-install.md; do
  [[ -f "$path" ]] || fail "missing file: $path"
done

require_text "$host" '../../modules/nixos/native-workstation.nix'
require_text "$host" '../../modules/nixos/native-proxy.nix'
require_text "$host" 'efi.efiSysMountPoint = "/boot";'
require_text "$host" 'time.hardwareClockInLocalTime = true;'
require_text "$hardware" 'boot.initrd.kernelModules = [ "amdgpu" ];'
require_text "$hardware" 'services.xserver.videoDrivers = [ "amdgpu" ];'
require_text "$hardware" 'boot.blacklistedKernelModules = ['
for driver in nouveau nvidia nvidia_drm nvidia_modeset nvidia_uvm; do
  require_text "$hardware" "\"$driver\""
done
if active_text "$hardware" | rg --quiet '(hardware\.nvidia|nvidia[[:space:]]*=)'; then
  fail 'physical must not configure the NVIDIA driver'
fi

# Both actual UUIDs and explicit template placeholders are permitted here.
for mount_point in / /boot; do
  require_text "$hardware" "\"$mount_point\".device = lib.mkForce \"/dev/disk/by-uuid/"
done
require_text "$proxy" 'services.mihomo = {'
require_text "$proxy" 'configFile = "/etc/mihomo/config.yaml";'
require_text "$proxy" 'tunMode = false;'
require_text "$proxy" 'default = "http://127.0.0.1:7890";'
require_text "$proxy" 'https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10'

# Host-specific network settings must never leak through a shared import.
proxy_imports=$(rg -l -F 'native-proxy.nix' hosts modules home --glob '*.nix')
[[ "$proxy_imports" == "$host" ]] || fail 'native-proxy must be imported only by physical'
network_owners=$(rg -l 'services\.mihomo|mirrors\.tuna\.tsinghua\.edu\.cn' hosts modules home --glob '*.nix')
[[ "$network_owners" == "$proxy" ]] || fail 'Mihomo and its cache must remain in native-proxy'

if active_text "$host" "$hardware" | rg --quiet 'boot\.loader\.grub|windows\.conf|os-prober'; then
  fail 'physical must use the firmware menu without Windows chainloading'
fi
if active_text "$proxy" | rg --quiet 'builtins\.readFile|environment\.etc|trusted-public-keys|require-sigs|trusted=true'; then
  fail 'proxy config must stay out of the store without changing cache trust'
fi

printf 'PASS: physical iGPU, disk and network isolation structure\n'
