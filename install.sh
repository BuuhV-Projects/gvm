#!/usr/bin/env bash
set -e

GVM_DIR="${GVM_DIR:-$HOME/.gvm}"
GVM_SOURCE_URL="${GVM_SOURCE_URL:-https://raw.githubusercontent.com/bruno-buuhvprojects/gvm/main/gvm.sh}"

gvm_installer_error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

gvm_installer_source_dir() {
  local source="${BASH_SOURCE[0]}"
  while [ -L "$source" ]; do
    local dir
    dir="$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd)"
    source="$(readlink "$source")"
    case "$source" in
      /*) ;;
      *) source="$dir/$source" ;;
    esac
  done
  cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd
}

gvm_update_profile() {
  local profile="$1"
  local source_line='export GVM_DIR="$HOME/.gvm"; [ -s "$GVM_DIR/gvm.sh" ] && . "$GVM_DIR/gvm.sh"'

  [ -n "$GVM_NO_UPDATE_PROFILE" ] && return 0
  [ -f "$profile" ] || return 1

  if grep -F '.gvm/scripts/gvm' "$profile" >/dev/null 2>&1; then
    sed -i.bak '/\.gvm\/scripts\/gvm/d' "$profile"
  fi

  if ! grep -F "$source_line" "$profile" >/dev/null 2>&1; then
    printf '\n%s\n' "$source_line" >> "$profile"
  fi
}

gvm_remove_legacy_layout() {
  [ "$GVM_KEEP_LEGACY" = "1" ] && return 0

  rm -rf \
    "$GVM_DIR/archive" \
    "$GVM_DIR/bin" \
    "$GVM_DIR/environments" \
    "$GVM_DIR/gos" \
    "$GVM_DIR/logs" \
    "$GVM_DIR/pkgsets" \
    "$GVM_DIR/scripts"
}

command -v curl >/dev/null 2>&1 || gvm_installer_error "curl is required"

mkdir -p "$GVM_DIR"
gvm_remove_legacy_layout

script_dir="$(gvm_installer_source_dir)"
if [ -f "$script_dir/gvm.sh" ]; then
  cp "$script_dir/gvm.sh" "$GVM_DIR/gvm.sh"
else
  curl -fL "$GVM_SOURCE_URL" -o "$GVM_DIR/gvm.sh" ||
    gvm_installer_error "Failed to download gvm.sh from $GVM_SOURCE_URL"
fi

chmod +x "$GVM_DIR/gvm.sh"

if [ -z "$GVM_NO_UPDATE_PROFILE" ]; then
  gvm_update_profile "$HOME/.bashrc" ||
    gvm_update_profile "$HOME/.bash_profile" ||
    gvm_update_profile "$HOME/.zshrc" ||
    true
fi

printf 'Installed GVM at %s\n' "$GVM_DIR"
printf 'Run this now:\n'
printf '  source "%s/gvm.sh"\n' "$GVM_DIR"
