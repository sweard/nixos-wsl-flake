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

printf '\n%s\n' '== WSL / WSLg =='
printf 'WSL_INTEROP=%s\n' "${WSL_INTEROP:-<未设置>}"
printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-<未设置>}"
printf 'DISPLAY=%s\n' "${DISPLAY:-<未设置>}"
printf 'ANDROID_SDK_ROOT=%s\n' "${ANDROID_SDK_ROOT:-<未设置>}"
printf 'JAVA_HOME=%s\n' "${JAVA_HOME:-<未设置>}"

if command -v glxinfo >/dev/null 2>&1; then
  printf '\n%s\n' '== OpenGL =='
  glxinfo -B 2>/dev/null | sed -n '1,14p'
fi

if command -v docker >/dev/null 2>&1; then
  printf '\n%s\n' '== Docker =='
  docker info --format 'Server={{.ServerVersion}} Driver={{.Driver}}' 2>/dev/null || printf '%s\n' 'Docker daemon 尚未就绪'
fi

exit "$missing"
