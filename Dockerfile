# syntax=docker/dockerfile:1.10
# check=skip=SecretsUsedInArgOrEnv
# (PASSWORD below is a public default for the container user, not a secret.)

ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

ARG UBUNTU_VERSION
ARG KAS_VERSION=4.7
ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=yocto
ARG UID=1000
ARG GID=1000
ARG PASSWORD=ubuntu

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80retries \
 && echo 'Acquire::http::Timeout "30";' >> /etc/apt/apt.conf.d/80retries

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    apt-get update && apt-get install -y --no-install-recommends \
      gawk wget git diffstat unzip texinfo gcc build-essential \
      chrpath socat cpio python3 python3-pip python3-pexpect \
      xz-utils debianutils iputils-ping python3-git python3-jinja2 \
      python3-subunit zstd file locales libacl1 \
      openssh-client \
      ca-certificates sudo vim less bzip2 rsync \
 && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen en_US.UTF-8

# Not required by Yocto and may be missing or renamed on newer releases, so
# install only where available. 25.10+ defaults to Rust uutils coreutils;
# Yocto's host tools are tested against GNU coreutils, so switch back. The
# two conflict and uutils is essential: apt 3's solver won't drop it on its
# own, so remove it explicitly in the same transaction (trailing '-').
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && PKGS="" \
 && for p in lsb-release python3-newt; do \
      if apt-cache show "$p" >/dev/null 2>&1; then PKGS="$PKGS $p"; fi; \
    done \
 && if [ -n "$PKGS" ]; then apt-get install -y --no-install-recommends $PKGS; fi \
 && if apt-cache show coreutils-from-gnu >/dev/null 2>&1; then \
      apt-get install -y --no-install-recommends --allow-remove-essential \
        coreutils-from-gnu coreutils-from-uutils-; \
    fi

# lz4 CLI: only 'liblz4-tool' exists on 18.04; 20.04 split out 'lz4' and
# later releases dropped the liblz4-tool transitional package.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    if [ "${UBUNTU_VERSION}" = "18.04" ]; then LZ4_PKG=liblz4-tool; else LZ4_PKG=lz4; fi; \
    apt-get update && apt-get install -y --no-install-recommends "$LZ4_PKG"

# Python 2.7 for pre-dunfell recipes that invoke python-native / python2.
# 18.04 only: python-minimal provides the unversioned /usr/bin/python symlink
# that old bitbake host-tooling checks for. Dropped from 20.04+.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    if [ "${UBUNTU_VERSION}" = "18.04" ]; then \
      apt-get update && apt-get install -y --no-install-recommends \
        python2.7 python-minimal; \
    fi

# setpriv (used by the entrypoint to drop root) is part of util-linux on older
# releases and a separate package on newer ones.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    command -v setpriv >/dev/null || { \
      apt-get update && apt-get install -y --no-install-recommends setpriv; \
    }

# 24.04+ ships a stock 'ubuntu' user squatting on UID 1000
RUN if id -u ubuntu >/dev/null 2>&1 && [ "$(id -u ubuntu)" = "1000" ]; then \
      userdel -r ubuntu 2>/dev/null || true; \
    fi; \
    ! id -u ubuntu >/dev/null 2>&1

# kas 4.x needs Python 3.8+; 18.04 ships 3.6, so pin kas 2.x there.
# pip<21 because pip 21+ drops Python 3.6 support.
# PEP 668 blocks system pip installs from 24.04 (Python 3.11+) onward,
# including 26.04.
RUN PY_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)'); \
    KV="${KAS_VERSION}"; \
    if [ "$PY_MINOR" -lt 8 ]; then \
      KV="2.6.3"; \
      python3 -m pip install --no-cache-dir --upgrade "pip<21.0" "setuptools<51.0"; \
    fi; \
    PIP_FLAGS=""; \
    if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)'; then \
      PIP_FLAGS="--break-system-packages"; \
    fi; \
    python3 -m pip install --no-cache-dir $PIP_FLAGS "kas==${KV}" \
 && mkdir -p /usr/share/doc/kas \
 && python3 -m pip freeze > /usr/share/doc/kas/pip-freeze.txt

# Fallback identity for bitbake/devtool commits; yocto-shell overrides it
# with the host user's git identity when one is configured.
RUN git config --system user.name "kas" \
 && git config --system user.email "kas@container"

RUN groupadd -g $GID $USERNAME \
 && useradd -m -u $UID -g $GID -s /bin/bash $USERNAME \
 && echo "$USERNAME:$PASSWORD" | chpasswd \
 && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
 && chmod 0440 /etc/sudoers.d/$USERNAME \
 && mkdir -p /workdir /downloads /sstate \
 && chown $UID:$GID /workdir /downloads /sstate

LABEL org.opencontainers.image.source="https://github.com/RajasJoshi/Yocto-builder"
LABEL org.opencontainers.image.description="Yocto build environment (Ubuntu ${UBUNTU_VERSION}, kas ${KAS_VERSION})"
LABEL org.opencontainers.image.licenses="MIT"

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER $USERNAME
WORKDIR /workdir
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]