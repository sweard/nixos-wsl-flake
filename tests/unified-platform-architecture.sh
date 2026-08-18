#!/usr/bin/env bash
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=${UNIFIED_ARCH_REPO:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

active_text() {
  sed -E '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//; s/[[:space:]]+\/\/.*$//' "$1"
}

require_file() {
  local path=$1
  [[ -f "$REPO_ROOT/$path" ]] || fail "missing file: $path"
}

require_text() {
  local path=$1 text=$2 description=$3
  if [[ ! -f "$REPO_ROOT/$path" ]]; then
    fail "$description (missing file: $path)"
  elif ! active_text "$REPO_ROOT/$path" | rg -F --quiet -- "$text"; then
    fail "$description (missing '$text' in $path)"
  fi
}

forbid_text() {
  local path=$1 text=$2 description=$3
  if [[ -f "$REPO_ROOT/$path" ]] && active_text "$REPO_ROOT/$path" | rg -F --quiet -- "$text"; then
    fail "$description (found '$text' in $path)"
  fi
}

for path in \
  home/common.nix \
  home/linux.nix \
  home/darwin.nix \
  home/native-desktop.nix \
  hosts/macbook/default.nix \
  modules/home-manager.nix \
  modules/darwin/base.nix \
  modules/darwin/homebrew.nix \
  modules/nixos/wsl-proxy.nix; do
  require_file "$path"
done

require_text flake.nix 'nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";' \
  'Darwin uses its stable nixpkgs channel'
require_text flake.nix 'url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";' \
  'nix-darwin stable input is declared'
require_text flake.nix 'nix-homebrew.url = "github:zhaofengli/nix-homebrew";' \
  'nix-homebrew input is declared'
require_text flake.nix 'darwinConfigurations' 'Darwin configuration output exists'
require_text flake.nix 'homeProfile = ./home/linux.nix;' 'WSL selects the Linux Home profile'
require_text flake.nix 'homeProfile = ./home/native-desktop.nix;' \
  'native NixOS selects the desktop Home profile'
require_text flake.nix 'homeProfile = ./home/darwin.nix;' 'macOS selects the Darwin Home profile'

require_text home/linux.nix './common.nix' 'Linux Home profile imports common Home config'
require_text home/darwin.nix './common.nix' 'Darwin Home profile imports common Home config'
require_text home/native-desktop.nix './linux.nix' \
  'native desktop Home profile extends Linux Home config'
require_text home/native-desktop.nix './modules/desktop/noctalia.nix' \
  'native desktop Home profile owns Noctalia user config'
require_text modules/home-manager.nix 'users.${userSettings.username} = import homeProfile;' \
  'shared Home Manager wiring imports the selected profile'

require_text hosts/macbook/default.nix '../../modules/darwin/base.nix' \
  'MacBook imports the Darwin base module'
require_text hosts/macbook/default.nix '../../modules/home-manager.nix' \
  'MacBook imports the shared Home Manager wiring'
require_text hosts/macbook/default.nix '../../modules/darwin/homebrew.nix' \
  'MacBook imports the Homebrew module'

require_text hosts/wsl/default.nix '../../modules/nixos/wsl-proxy.nix' \
  'WSL host imports the WSL proxy module'
[[ ! -e "$REPO_ROOT/modules/nixos/proxy.nix" ]] || fail 'legacy generic proxy module still exists'
forbid_text modules/nixos/base.nix 'env_keep' 'NixOS base must not contain proxy sudo rules'
require_text modules/nixos/wsl-proxy.nix 'env_keep' 'WSL proxy owns proxy sudo rules'
forbid_text modules/nixos/native-desktop.nix 'home-manager.users' \
  'NixOS desktop module must not mutate the Home Manager profile'
proxy_import_count=$(rg -F -l -- '../../modules/nixos/wsl-proxy.nix' "$REPO_ROOT/hosts" | wc -l | tr -d ' ')
[[ "$proxy_import_count" == 1 ]] || \
  fail "WSL proxy must have exactly one host import (found $proxy_import_count)"
[[ ! -e "$REPO_ROOT/modules/nixos/home-manager.nix" ]] || \
  fail 'Home Manager wiring is still duplicated under modules/nixos'
[[ ! -e "$REPO_ROOT/modules/darwin/home-manager.nix" ]] || \
  fail 'Home Manager wiring is still duplicated under modules/darwin'

if (( failures > 0 )); then
  printf 'SUMMARY: %d architecture check(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'PASS: unified NixOS / Darwin architecture\n'
