#!/usr/bin/env bash
set -u

# Structural regression checks for the Niri + Noctalia native desktop.
# The repository is inferred from this script's parent directory unless the
# task-specific NIRI_NOCTALIA_REPO override is supplied.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=${NIRI_NOCTALIA_REPO:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}

failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_file() {
  local file=$1
  [[ -f "$file" ]] || fail "missing required file: ${file#$REPO_ROOT/}"
}

require_fixed() {
  local file=$1 needle=$2 description=$3
  if [[ ! -f "$file" ]]; then
    fail "$description (file missing: ${file#$REPO_ROOT/})"
  elif ! active_text "$file" | rg -F --quiet -- "$needle"; then
    fail "$description (missing: $needle in ${file#$REPO_ROOT/})"
  fi
}

# Ignore comments when checking active configuration. This deliberately does
# not scan docs/, where historical architecture notes retain old component
# names for context.
active_text() {
  sed -E '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//; s/[[:space:]]+\/\/.*$//' "$1"
}

require_count() {
  local file=$1 needle=$2 expected=$3 description=$4 count
  if [[ ! -f "$file" ]]; then
    fail "$description (file missing: ${file#$REPO_ROOT/})"
    return
  fi
  count=$(active_text "$file" | rg -F -o -- "$needle" | wc -l | tr -d ' ')
  if [[ "$count" != "$expected" ]]; then
    fail "$description (expected $expected occurrence(s), found $count in ${file#$REPO_ROOT/})"
  fi
}

noctalia_config() {
  local file=$1
  active_text "$file" | awk '
    /programs\.noctalia[[:space:]]*=/ {
      in_block = 1
      print
      next
    }
    in_block {
      print
      if ($0 ~ /^[[:space:]]*};/) exit
    }
  '
}

noctalia_top_level() {
  local file=$1
  active_text "$file" | awk '
    !started && /programs\.noctalia[[:space:]]*=[[:space:]]*\{/ {
      started = 1
      depth = 1
      next
    }
    started {
      if (depth == 1 && $0 ~ /[[:alnum:]_-]+[[:space:]]*=[[:space:]]*\{/) {
        child = $0
        sub(/[[:space:]]*=.*/, "", child)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", child)
        rest = $0
        sub(/^[^{]*\{/, "", rest)
        sub(/\}.*/, "", rest)
        if (rest ~ /[^[:space:]]/) print child "." rest
      } else if (depth == 2 && child != "" && $0 !~ /\{/) {
        print child "." $0
      } else if (depth == 1 && $0 !~ /\{/) {
        print
      }
      opens = gsub(/\{/, "{")
      closes = gsub(/\}/, "}")
      depth += opens - closes
      if (depth <= 1) child = ""
      if (depth <= 0) exit
    }
  '
}

require_noctalia_setting() {
  local file=$1 setting=$2 value=$3 description=$4 compact dotted block
  if [[ ! -f "$file" ]]; then
    fail "$description (file missing: ${file#$REPO_ROOT/})"
    return
  fi
  compact=$(active_text "$file" | sed -E 's/[[:space:]]+//g')
  dotted="programs.noctalia.${setting}=${value};"
  block=$(noctalia_top_level "$file" | sed -E 's/[[:space:]]+//g')
  if ! rg -F --quiet -- "$dotted" <<<"$compact" && \
     ! rg -F -x --quiet -- "${setting}=${value};" <<<"$block"; then
    fail "$description (expected Noctalia setting ${setting} = ${value})"
  fi
}

forbid_noctalia_service() {
  local file=$1 description=$2
  if [[ ! -f "$file" ]]; then
    return
  fi
  if active_text "$file" | rg -F --quiet -- 'systemd.user.services.noctalia'; then
    fail "$description (dotted noctalia user service)"
    return
  fi
  if active_text "$file" | awk '
      /systemd\.user\.services[[:space:]]*=[[:space:]]*\{/ { inside = 1; depth = 0 }
      inside {
        if ($0 ~ /(^|[[:space:];])noctalia[[:space:]]*=/) found = 1
        opens = gsub(/\{/, "{")
        closes = gsub(/\}/, "}")
        depth += opens - closes
        if (depth <= 0) exit
      }
      END { exit(found ? 0 : 1) }
    '; then
    fail "$description (attribute-set noctalia user service)"
  fi
}

forbid_active() {
  local file=$1 needle=$2 description=$3
  if [[ -f "$file" ]] && active_text "$file" | rg -F --quiet -- "$needle"; then
    fail "$description (unexpected active text: $needle in ${file#$REPO_ROOT/})"
  fi
}

forbid_active_regex() {
  local file=$1 pattern=$2 description=$3
  if [[ -f "$file" ]] && active_text "$file" | rg --quiet -- "$pattern"; then
    fail "$description (unexpected active text in ${file#$REPO_ROOT/})"
  fi
}

if ! command -v rg >/dev/null 2>&1; then
  printf 'FAIL: ripgrep (rg) is required by this structural test\n' >&2
  exit 2
fi

if [[ ${NIRI_NOCTALIA_SELF_TEST:-0} == 1 ]]; then
  fixture=$(mktemp "${TMPDIR:-/tmp}/native-desktop-noctalia.XXXXXX")
  trap 'rm -f "$fixture"' EXIT
  printf '%s\n' 'programs.noctalia.enable = true;' >"$fixture"
  require_noctalia_setting "$fixture" enable true 'self-test dotted setting'
  printf '%s\n' 'programs.noctalia = {' '  enable = true;' '  package = null;' '  systemd.enable = false;' '};' >"$fixture"
  require_noctalia_setting "$fixture" enable true 'self-test top-level setting'
  printf '%s\n' 'programs.noctalia = {' '  systemd = {' '    enable = false;' '  };' '};' >"$fixture"
  require_noctalia_setting "$fixture" systemd.enable false 'self-test nested systemd setting'
  printf '%s\n' 'programs.noctalia = {' '  settings = { enable = true; };' '};' >"$fixture"
  before=$failures
  require_noctalia_setting "$fixture" enable true 'self-test nested settings.enable rejection' 2>/dev/null
  if [[ $failures -gt $before ]]; then
    failures=$before
  else
    fail 'self-test nested settings.enable unexpectedly passed'
  fi
  printf '%s\n' 'systemd.user.services = { unrelated = { wantedBy = [ "default.target" ]; }; };' >"$fixture"
  forbid_noctalia_service "$fixture" 'self-test unrelated user service allowed'
  printf '%s\n' \
    'systemd.user.services = {' \
    '  unrelated = {' \
    '    wantedBy = [ "default.target" ];' \
    '  };' \
    '};' \
    'noctalia = { unrelated = true; };' >"$fixture"
  forbid_noctalia_service "$fixture" 'self-test service block boundary'
  printf '%s\n' 'systemd.user.services = { noctalia = { wantedBy = [ "default.target" ]; }; };' >"$fixture"
  before=$failures
  forbid_noctalia_service "$fixture" 'self-test noctalia user service rejection' 2>/dev/null
  if [[ $failures -gt $before ]]; then
    failures=$before
  else
    fail 'self-test noctalia service unexpectedly allowed'
  fi
  if (( failures > 0 )); then exit 1; fi
  printf 'PASS: helper self-tests\n'
  exit 0
fi

FLAKE=$REPO_ROOT/flake.nix
NATIVE=$REPO_ROOT/modules/nixos/native-desktop.nix
NOCTALIA=$REPO_ROOT/home/modules/desktop/noctalia.nix
NATIVE_WORKSTATION=$REPO_ROOT/modules/nixos/native-workstation.nix
WSL_HOST=$REPO_ROOT/hosts/wsl/default.nix
WSL_MODULE=$REPO_ROOT/modules/nixos/wsl.nix
VMWARE_HOST=$REPO_ROOT/hosts/vmware/default.nix
PHYSICAL_HOST=$REPO_ROOT/hosts/physical/default.nix
README=$REPO_ROOT/README.md

# Keep the first RED failure tied to the missing feature requested by the
# brief: the official Noctalia Flake input.
require_fixed "$FLAKE" 'github:noctalia-dev/noctalia' \
  'Noctalia Flake input is declared'

for required in "$FLAKE" "$NATIVE" "$NATIVE_WORKSTATION" "$WSL_HOST" "$WSL_MODULE" "$VMWARE_HOST" "$PHYSICAL_HOST" "$README" "$NOCTALIA"; do
  require_file "$required"
done

# Report all independent missing files once, then stop before derived checks
# produce duplicate noise (especially for the not-yet-created HM module).
if (( failures > 0 )); then
  printf 'SUMMARY: %d structural check(s) failed\n' "$failures" >&2
  exit 1
fi

require_fixed "$NATIVE" 'inputs.noctalia.nixosModules.default' \
  'native NixOS module imports the official Noctalia module'
require_fixed "$NOCTALIA" 'inputs.noctalia.homeModules.default' \
  'native Home Manager module imports the official Noctalia module'
require_count "$NOCTALIA" 'spawn-at-startup "noctalia"' 1 \
  'Niri starts exactly one Noctalia instance from its startup config'

require_fixed "$NATIVE" 'services.greetd.enable = true;' \
  'native desktop uses greetd'
require_fixed "$NATIVE" 'tuigreet' \
  'greetd uses tuigreet'
require_fixed "$NOCTALIA" 'pkgs.ghostty' \
  'Home Manager installs the terminal referenced by the Niri config'
forbid_active "$NATIVE" 'ghostty' \
  'Ghostty is a user application and must not remain a NixOS system package'
require_fixed "$NATIVE" 'xwayland-satellite' \
  'xwayland-satellite remains the X11 compatibility layer'
require_noctalia_setting "$NATIVE" package null \
  'NixOS Noctalia module does not install a duplicate package'

# Noctalia owns the shell components; these old standalone packages/services
# must not remain active in the native desktop module.
for old_component in \
  'services.desktopManager.plasma6' \
  'services.displayManager.sddm' \
  'services.xserver' \
  'waybar' \
  'fuzzel' \
  'mako' \
  'swaylock' \
  'kdePackages.polkit-kde-agent-1'; do
  forbid_active "$NATIVE" "$old_component" \
    "old standalone component is removed from native desktop: $old_component"
done

# The NixOS module may be imported, but the package must be installed once by
# the native user's Home Manager module. A bare package item is an active
# duplicate; comments and historical docs are intentionally ignored.
forbid_active_regex "$NATIVE" '^[[:space:]]+noctalia[[:space:]]*$' \
  'Noctalia package is not duplicated in NixOS system packages'
require_noctalia_setting "$NOCTALIA" enable true \
  'Home Manager owns the Noctalia package'
require_noctalia_setting "$NOCTALIA" systemd.enable false \
  'Noctalia Home Manager systemd service is disabled'
forbid_noctalia_service "$NOCTALIA" \
  'Noctalia is not started by a duplicate Home Manager systemd service'
require_noctalia_setting "$NOCTALIA" settings.idle.behavior.lock.enabled true \
  'Noctalia enables its default 600-second idle lock behavior'
require_noctalia_setting "$NOCTALIA" settings.idle.behavior.lock.timeout 600 \
  'Noctalia keeps the default 600-second idle lock timeout'
require_noctalia_setting "$NOCTALIA" settings.idle.behavior.lock.action '"lock"' \
  'Noctalia keeps the default idle lock action'
require_noctalia_setting "$NOCTALIA" 'settings.idle.behavior."screen-off".enabled' true \
  'Noctalia enables its default 660-second idle screen-off behavior'
require_noctalia_setting "$NOCTALIA" 'settings.idle.behavior."screen-off".timeout' 660 \
  'Noctalia keeps the default 660-second idle screen-off timeout'
require_noctalia_setting "$NOCTALIA" 'settings.idle.behavior."screen-off".action' '"screen_off"' \
  'Noctalia keeps the default idle screen-off action'

# Native hosts share the native-workstation seam, which imports the desktop
# module; WSL stays on its own WSL-only composition.
require_fixed "$NATIVE_WORKSTATION" './native-desktop.nix' \
  'native-workstation imports the native desktop module'
for native_host in "$VMWARE_HOST" "$PHYSICAL_HOST"; do
  require_fixed "$native_host" '../../modules/nixos/native-workstation.nix' \
    "native host uses native-workstation: ${native_host#$REPO_ROOT/}"
done
forbid_active "$WSL_HOST" 'native-workstation.nix' \
  'WSL host does not import native-workstation'

# WSL remains isolated from the native desktop stack.
for wsl_file in "$WSL_HOST" "$WSL_MODULE"; do
  forbid_active "$wsl_file" 'noctalia' \
    "WSL does not reference Noctalia: ${wsl_file#$REPO_ROOT/}"
  forbid_active "$wsl_file" 'programs.niri' \
    "WSL does not enable native Niri: ${wsl_file#$REPO_ROOT/}"
done

# README assertions are intentionally narrow and scoped to README.md only;
# old names in docs/ are historical evidence, not active configuration.
for readme_key in 'Niri' 'Noctalia' 'greetd' '.#vmware' '.#physical' 'WSL'; do
  require_fixed "$README" "$readme_key" \
    "README documents the native Niri + Noctalia architecture ($readme_key)"
done
forbid_active "$README" 'systemctl --user status niri --no-pager' \
  'README does not claim greetd-launched Niri is a user systemd service'
require_fixed "$README" 'pgrep -a niri' \
  'README verifies the greetd-launched Niri process directly'

if (( failures > 0 )); then
  printf 'SUMMARY: %d structural check(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'PASS: native Niri + Noctalia structural checks\n'
