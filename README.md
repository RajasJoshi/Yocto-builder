# Yocto-builder

Yocto/OpenEmbedded build environment with kas, published to GHCR.

## Tags

| Tag | Base |
|---|---|
| `ubuntu-18.04` | Ubuntu 18.04 (kas 2.6.3, Python 2.7 for pre-dunfell) |
| `ubuntu-20.04` | Ubuntu 20.04 |
| `ubuntu-22.04`, `latest` | Ubuntu 22.04 (`latest` follows `DEFAULT_UBUNTU`) |
| `ubuntu-24.04` | Ubuntu 24.04 |
| `ubuntu-26.04` | Ubuntu 26.04 |

`linux/amd64` only; Linux hosts only.

## Quick start

    ./yocto-shell                          # 22.04, cwd mounted at /workdir
    ./yocto-shell -u 24.04
    ./yocto-shell -w ~/projects/bsp

The container runs as your host uid/gid (the `yocto` user is remapped at
startup), so files in `/workdir` stay owned by you. Run `kas build` etc.
from the shell.

Downloads and sstate persist in `~/.yocto-cache` across runs. Override with
`-c DIR` or `YOCTO_CACHE`.

## User

The container user is `yocto`, password `ubuntu` (passwordless `sudo` is
also enabled). Override at build time with `--build-arg PASSWORD=...`.

Commits made in the container use your host `git config --global`
`user.name`/`user.email` (fallback: `kas <kas@container>`). Under `sudo`, run
`sudo --preserve-env=SSH_AUTH_SOCK ./yocto-shell` to keep your ssh-agent.

The exact Python packages installed alongside kas are listed in
`/usr/share/doc/kas/pip-freeze.txt` inside the image.

## Behind a proxy

Set `http_proxy` / `https_proxy` / `no_proxy` in your shell; `yocto-shell`
forwards them and lists them in `BB_ENV_PASSTHROUGH_ADDITIONS` so bitbake
doesn't strip them.

Pre-kirkstone releases use the old name; run
`export BB_ENV_EXTRAWHITE="$BB_ENV_PASSTHROUGH_ADDITIONS"` in the shell first
(kas handles this itself). Don't set it for kirkstone or newer: bitbake
rejects it.

## Using the cache mounts

`yocto-shell` exports `DL_DIR=/downloads` and `SSTATE_DIR=/sstate` and adds
them to the bitbake passthrough list, so the defaults in `bitbake.conf`
(`DL_DIR ?= ...`) pick them up. kas forwards both variables on its own. No
`local.conf` changes are needed, unless it hard-assigns them with `=`; in
that case change those lines to `?=` or remove them.

## Bumping versions

Edit `versions.env`. The build matrix and the default for `yocto-shell` both
read from it.

## CI

`build-image` builds every Ubuntu version on push, pull request, and weekly.
Each image is tested before it is pushed: a smoke test (kas on PATH, non-root,
locale, writable workdir) and a uid-remap test. Pull requests build and test
but don't push.
