#!/usr/bin/env bash

# GVM is intentionally implemented as a shell function, like nvm.
# Commands such as `gvm use` must run in the current shell to update PATH.

export GVM_DIR="${GVM_DIR:-$HOME/.gvm}"
export GVM_VERSION="2.0.0"

gvm_error() {
  printf 'ERROR: %s\n' "$*" >&2
}

gvm_info() {
  printf '%s\n' "$*"
}

gvm_mkdirs() {
  mkdir -p "$GVM_DIR/versions/go" "$GVM_DIR/cache/bin" "$GVM_DIR/alias"
}

gvm_normalize_version() {
  case "$1" in
    go*) printf '%s\n' "$1" ;;
    v*) printf 'go%s\n' "${1#v}" ;;
    *) printf 'go%s\n' "$1" ;;
  esac
}

gvm_platform() {
  case "$(uname -s)" in
    Darwin*) printf 'darwin\n' ;;
    Linux*) printf 'linux\n' ;;
    MINGW* | MSYS* | CYGWIN* | WIN32*) printf 'windows\n' ;;
    *) gvm_error "Unsupported OS: $(uname -s)"; return 1 ;;
  esac
}

gvm_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) printf 'amd64\n' ;;
    arm64 | aarch64) printf 'arm64\n' ;;
    i386 | i686) printf '386\n' ;;
    armv6l) printf 'armv6l\n' ;;
    *) gvm_error "Unsupported architecture: $(uname -m)"; return 1 ;;
  esac
}

gvm_archive_ext() {
  case "$1" in
    windows) printf 'zip\n' ;;
    *) printf 'tar.gz\n' ;;
  esac
}

gvm_version_dir() {
  printf '%s/versions/go/%s\n' "$GVM_DIR" "$1"
}

gvm_strip_go_paths() {
  local old_path="$PATH"
  local new_path=""
  local entry

  while [ -n "$old_path" ]; do
    entry="${old_path%%:*}"
    if [ "$old_path" = "$entry" ]; then
      old_path=""
    else
      old_path="${old_path#*:}"
    fi

    case "$entry" in
      "$GVM_DIR"/versions/go/*/bin) ;;
      "")
        [ -z "$new_path" ] && new_path="$entry" || new_path="$new_path:$entry"
        ;;
      *)
        [ -z "$new_path" ] && new_path="$entry" || new_path="$new_path:$entry"
        ;;
    esac
  done

  printf '%s\n' "$new_path"
}

gvm_resolve_version() {
  local version="$1"

  if [ -z "$version" ] || [ "$version" = "default" ]; then
    if [ -f "$GVM_DIR/alias/default" ]; then
      version="$(sed -n '1p' "$GVM_DIR/alias/default")"
    else
      gvm_error "No version specified and no default alias found"
      return 1
    fi
  fi

  gvm_normalize_version "$version"
}

gvm_install() {
  local version platform arch ext file url cache_path tmp_dir dest

  version="$(gvm_resolve_version "$1")" || return 1
  platform="$(gvm_platform)" || return 1
  arch="$(gvm_arch)" || return 1
  ext="$(gvm_archive_ext "$platform")"
  file="${version}.${platform}-${arch}.${ext}"
  url="${GVM_GO_DOWNLOAD_URL:-https://go.dev/dl}/${file}"
  cache_path="$GVM_DIR/cache/bin/$file"
  tmp_dir="$GVM_DIR/cache/install-$version"
  dest="$(gvm_version_dir "$version")"

  if [ -x "$dest/bin/go" ] || [ -x "$dest/bin/go.exe" ]; then
    gvm_info "$version is already installed"
    gvm_info "Run 'gvm use $version' to start using this Go version."
    return 0
  fi

  command -v curl >/dev/null 2>&1 || { gvm_error "curl is required"; return 1; }
  if [ "$ext" = "zip" ]; then
    command -v unzip >/dev/null 2>&1 || { gvm_error "unzip is required to install Go on Windows"; return 1; }
  else
    command -v tar >/dev/null 2>&1 || { gvm_error "tar is required"; return 1; }
  fi

  gvm_mkdirs
  rm -rf "$tmp_dir" "$dest"
  mkdir -p "$tmp_dir" "$dest"

  if [ ! -f "$cache_path" ]; then
    gvm_info "Downloading $url"
    curl -fL "$url" -o "$cache_path" || {
      rm -rf "$tmp_dir" "$dest" "$cache_path"
      gvm_error "Failed to download $file"
      return 1
    }
  fi

  gvm_info "Installing $version"
  if [ "$ext" = "zip" ]; then
    unzip -q "$cache_path" -d "$tmp_dir" || {
      rm -rf "$tmp_dir" "$dest"
      gvm_error "Failed to extract $file"
      return 1
    }
    cp -R "$tmp_dir/go/." "$dest" || {
      rm -rf "$tmp_dir" "$dest"
      gvm_error "Failed to install $version"
      return 1
    }
  else
    tar -xzf "$cache_path" -C "$dest" --strip-components 1 || {
      rm -rf "$tmp_dir" "$dest"
      gvm_error "Failed to extract $file"
      return 1
    }
  fi

  rm -rf "$tmp_dir"
  gvm_info "$version installed"
  gvm_info "Run 'gvm use $version' to start using this Go version."
}

gvm_use() {
  local version dir go_bin

  version="$(gvm_resolve_version "$1")" || return 1
  dir="$(gvm_version_dir "$version")"

  if [ ! -d "$dir" ]; then
    gvm_error "$version is not installed. Run 'gvm install $version'."
    return 1
  fi

  if [ -x "$dir/bin/go.exe" ]; then
    go_bin="$dir/bin/go.exe"
  elif [ -x "$dir/bin/go" ]; then
    go_bin="$dir/bin/go"
  else
    gvm_error "$version is missing a Go binary"
    return 1
  fi

  export GOROOT="$dir"
  export GVM_CURRENT="$version"
  export PATH
  PATH="$(gvm_strip_go_paths)"
  PATH="$dir/bin:$PATH"

  gvm_info "Now using $version"
  "$go_bin" version
}

gvm_current() {
  if [ -n "$GVM_CURRENT" ]; then
    printf '%s\n' "$GVM_CURRENT"
    return 0
  fi

  if command -v go >/dev/null 2>&1; then
    go version
  else
    printf 'none\n'
  fi
}

gvm_list() {
  local current version dir

  current="${GVM_CURRENT:-}"
  if [ ! -d "$GVM_DIR/versions/go" ]; then
    gvm_info "No Go versions installed"
    return 0
  fi

  for dir in "$GVM_DIR"/versions/go/*; do
    [ -d "$dir" ] || continue
    version="${dir##*/}"
    if [ "$version" = "$current" ]; then
      printf '-> %s\n' "$version"
    else
      printf '   %s\n' "$version"
    fi
  done
}

gvm_ls_remote() {
  command -v curl >/dev/null 2>&1 || { gvm_error "curl is required"; return 1; }
  curl -fsSL 'https://go.dev/dl/?mode=json' |
    sed -n 's/.*"version": "\(go[^"]*\)".*/\1/p'
}

gvm_alias() {
  local name="$1"
  local version="$2"

  if [ -z "$name" ]; then
    for alias_file in "$GVM_DIR"/alias/*; do
      [ -f "$alias_file" ] || continue
      printf '%s -> %s\n' "${alias_file##*/}" "$(sed -n '1p' "$alias_file")"
    done
    return 0
  fi

  if [ -z "$version" ]; then
    [ -f "$GVM_DIR/alias/$name" ] || { gvm_error "Alias not found: $name"; return 1; }
    sed -n '1p' "$GVM_DIR/alias/$name"
    return 0
  fi

  version="$(gvm_normalize_version "$version")"
  gvm_mkdirs
  printf '%s\n' "$version" > "$GVM_DIR/alias/$name"
  gvm_info "$name -> $version"
}

gvm_uninstall() {
  local version dir

  version="$(gvm_resolve_version "$1")" || return 1
  dir="$(gvm_version_dir "$version")"

  if [ ! -d "$dir" ]; then
    gvm_error "$version is not installed"
    return 1
  fi

  if [ "$GVM_CURRENT" = "$version" ]; then
    gvm_error "Cannot uninstall the active version. Run 'gvm use <other-version>' first."
    return 1
  fi

  rm -rf "$dir"
  gvm_info "Uninstalled $version"
}

gvm_which() {
  local version dir

  version="$(gvm_resolve_version "$1")" || return 1
  dir="$(gvm_version_dir "$version")"

  if [ -x "$dir/bin/go.exe" ]; then
    printf '%s/bin/go.exe\n' "$dir"
  elif [ -x "$dir/bin/go" ]; then
    printf '%s/bin/go\n' "$dir"
  else
    gvm_error "$version is not installed"
    return 1
  fi
}

gvm_help() {
  cat <<'EOF'
Usage: gvm <command> [args]

Commands:
  install <version>       Download and install a Go binary release
  use <version|default>   Use an installed Go version in this shell
  list, ls                List installed Go versions
  ls-remote               List remote Go versions
  current                 Show the active Go version
  alias [name] [version]  Manage aliases, including "default"
  uninstall <version>     Remove an installed Go version
  which <version>         Print the Go binary path for a version
  version                 Print GVM version
  help                    Show this help

Examples:
  gvm install go1.22.5
  gvm use go1.22.5
  gvm alias default go1.22.5
EOF
}

gvm() {
  gvm_mkdirs

  case "$1" in
    install) shift; gvm_install "$@" ;;
    use) shift; gvm_use "$@" ;;
    list | ls) gvm_list ;;
    ls-remote | list-remote) gvm_ls_remote ;;
    current) gvm_current ;;
    alias) shift; gvm_alias "$@" ;;
    uninstall | remove | rm) shift; gvm_uninstall "$@" ;;
    which) shift; gvm_which "$@" ;;
    version | --version) printf '%s\n' "$GVM_VERSION" ;;
    help | --help | -h | "") gvm_help ;;
    *) gvm_error "Unknown command: $1"; gvm_help; return 1 ;;
  esac
}

if [ -f "$GVM_DIR/alias/default" ] && [ -z "$GVM_NO_USE_DEFAULT" ]; then
  gvm_use default >/dev/null 2>&1 || true
fi
