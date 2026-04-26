# gvm

Go Version Manager inspired by `nvm`.

This rewrite keeps GVM small: it installs official Go binary releases and
switches versions by updating the current shell environment.

## Install

From a local checkout:

```bash
bash ./install.sh
```

Or from GitHub:

```bash
bash < <(curl -fsSL https://raw.githubusercontent.com/BuuhV-Projects/gvm/main/install.sh)
```

Add this to your shell profile if the installer did not add it automatically:

```bash
export GVM_DIR="$HOME/.gvm"
[ -s "$GVM_DIR/gvm.sh" ] && . "$GVM_DIR/gvm.sh"
```

## Usage

```bash
gvm install go1.26.2
gvm use go1.26.2
gvm alias default go1.26.2
gvm current
gvm list
gvm ls-remote
gvm uninstall go1.26.2
```

Versions can be passed with or without the `go` prefix:

```bash
gvm install 1.26.2
gvm use go1.26.2
```

## Windows

Use Git Bash, MSYS2, or Cygwin. On Windows, GVM downloads official
`windows-amd64.zip` or `windows-arm64.zip` releases and expects `curl` and
`unzip` to be available in the shell.

## Directory Layout

```text
~/.gvm/
  gvm.sh
  versions/
    go/
      go1.26.2/
  alias/
    default
  cache/
    bin/
```

## Commands

```text
gvm install <version>       Download and install a Go binary release
gvm use <version|default>   Use an installed Go version in this shell
gvm list                    List installed Go versions
gvm ls-remote               List remote Go versions
gvm current                 Show the active Go version
gvm alias [name] [version]  Manage aliases, including "default"
gvm uninstall <version>     Remove an installed Go version
gvm which <version>         Print the Go binary path for a version
gvm version                 Print GVM version
```
