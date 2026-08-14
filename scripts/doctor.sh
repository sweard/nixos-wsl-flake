#!/usr/bin/env bash
set -uo pipefail

missing=0

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf 'OK      %-18s %s\n' "$name" "$(command -v "$name")"
  else
    printf 'MISSING %-18s\n' "$name"
    missing=$((missing + 1))
  fi
}

printf '%s\n' '== 开发工具 =='
for command_name in git git-lfs java gradle kotlin adb cmake ninja clang gcc lldb gdb rustc cargo rust-analyzer node pnpm python3 docker flutter zsh; do
  check_command "$command_name"
done

printf '\n%s\n' '== 系统 / 会话 =='
printf 'HOSTNAME=%s\n' "$(hostname)"
if command -v systemd-detect-virt >/dev/null 2>&1; then
  virtualization="$(systemd-detect-virt 2>/dev/null || true)"
  printf 'VIRTUALIZATION=%s\n' "${virtualization:-none}"
fi
printf 'WSL_INTEROP=%s\n' "${WSL_INTEROP:-<未设置>}"
printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-<未设置>}"
printf 'DISPLAY=%s\n' "${DISPLAY:-<未设置>}"
printf 'XDG_SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE:-<未设置>}"
printf 'XDG_CURRENT_DESKTOP=%s\n' "${XDG_CURRENT_DESKTOP:-<未设置>}"
printf 'ANDROID_SDK_ROOT=%s\n' "${ANDROID_SDK_ROOT:-<未设置>}"
printf 'JAVA_HOME=%s\n' "${JAVA_HOME:-<未设置>}"

if command -v glxinfo >/dev/null 2>&1; then
  printf '\n%s\n' '== OpenGL =='
  glxinfo -B 2>/dev/null | sed -n '1,14p'
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  printf '\n%s\n' '== NVIDIA =='
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true
fi

if command -v vmware-toolbox-cmd >/dev/null 2>&1; then
  printf '\n%s\n' '== VMware Tools =='
  vmware-toolbox-cmd -v 2>/dev/null || true
fi

if command -v docker >/dev/null 2>&1; then
  printf '\n%s\n' '== Docker =='
  docker info --format 'Server={{.ServerVersion}} Driver={{.Driver}}' 2>/dev/null || printf '%s\n' 'Docker daemon 尚未就绪'
fi

exit "$missing"
