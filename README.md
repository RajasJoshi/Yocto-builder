# yocto-container

Yocto/OpenEmbedded build environment with kas, published to GHCR.

## Tags

| Tag | Base |
|---|---|
| `ubuntu-20.04` | Ubuntu 20.04 |
| `ubuntu-22.04`, `latest` | Ubuntu 22.04 |
| `ubuntu-24.04` | Ubuntu 24.04 |

`linux/amd64` and `linux/arm64`.

## Quick start

    ./yocto-shell                          # 22.04, cwd mounted at /workdir
    ./yocto-shell -u 24.04
    ./yocto-shell -w ~/projects/bsp
    ./yocto-shell -- kas build kas-project.yml

Downloads and sstate persist in `~/.yocto-cache` across runs. Override with
`-c DIR` or `YOCTO_CACHE`.

## Behind a proxy

Set `http_proxy` / `https_proxy` / `no_proxy` in your shell; `yocto-shell`
forwards them and adds them to `BB_ENV_PASSTHROUGH_ADDITIONS` so bitbake
doesn't strip them.

## Using the cache mounts

The container sets `DL_DIR=/downloads` and `SSTATE_DIR=/sstate`, but bitbake
ignores env vars unless `local.conf` reads them:

    DL_DIR ?= "${@os.getenv('DL_DIR') or '${TOPDIR}/downloads'}"
    SSTATE_DIR ?= "${@os.getenv('SSTATE_DIR') or '${TOPDIR}/sstate-cache'}"

With kas:

    local_conf_header:
      paths: |
        DL_DIR = "/downloads"
        SSTATE_DIR = "/sstate"

## Bumping versions

Edit `versions.env`. The build matrix and the default for `yocto-shell` both
read from it.

## CI

- `build-image` — builds all Ubuntu versions on push, plus a smoke test
  (kas on PATH, non-root, locale, writable workdir).
- `poky-build` — weekly `core-image-minimal` build against scarthgap. Runs on
  a hosted runner; expect ~4h and disk pressure. Move to a self-hosted runner
  if it starts timing out.