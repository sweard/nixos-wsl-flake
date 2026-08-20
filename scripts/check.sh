#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$REPO_ROOT"

bash tests/native-desktop-noctalia.sh
bash tests/unified-platform-architecture.sh

if ! command -v nix >/dev/null 2>&1; then
  printf 'FAIL: Nix is required for lock validation and real module evaluation\n' >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'FAIL: jq is required to inspect flake.lock\n' >&2
  exit 2
fi

for input in nixpkgs-darwin nix-darwin nix-homebrew; do
  if ! jq -e --arg input "$input" '.nodes.root.inputs | has($input)' flake.lock >/dev/null; then
    printf 'FAIL: flake.lock is missing root input %s\n' "$input" >&2
    exit 1
  fi
done

nix_flags=(--extra-experimental-features "nix-command flakes")
nix "${nix_flags[@]}" flake show --no-write-lock-file . >/dev/null

for attribute in \
  nixosConfigurations.wsl.config.system.build.toplevel.drvPath \
  nixosConfigurations.vmware.config.system.build.toplevel.drvPath \
  nixosConfigurations.physical.config.system.build.toplevel.drvPath \
  darwinConfigurations.Jeffs-MacBook-Pro.system.drvPath \
  homeConfigurations.jeff-aarch64-linux.activationPackage.drvPath; do
  nix "${nix_flags[@]}" eval --raw ".#$attribute" >/dev/null
  printf 'PASS: evaluated %s\n' "$attribute"
done

printf 'PASS: lock and all host evaluations\n'
