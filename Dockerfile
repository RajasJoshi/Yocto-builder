# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

ARG UBUNTU_VERSION
ARG KAS_VERSION=4.7
ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=yocto
ARG UID=1000
ARG GID=1000

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    apt-get update && apt-get install -y --no-install-recommends \
      gawk wget git diffstat unzip texinfo gcc build-essential \
      chrpath socat cpio python3 python3-pip python3-pexpect \
      xz-utils debianutils iputils-ping python3-git python3-jinja2 \
      python3-subunit zstd liblz4-tool file locales libacl1 \
      python3-newt lsb-release \
      ca-certificates sudo vim less bzip2 lz4 rsync \
 && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen en_US.UTF-8

# 24.04+ ships a stock 'ubuntu' user squatting on UID 1000
RUN if id -u ubuntu >/dev/null 2>&1 && [ "$(id -u ubuntu)" = "1000" ]; then \
      touch /var/mail/ubuntu 2>/dev/null || true; \
      userdel -r ubuntu 2>/dev/null || userdel ubuntu; \
    fi

# PEP 668 blocks system pip installs from 24.04 onward
RUN PIP_FLAGS=""; \
    if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)'; then \
      PIP_FLAGS="--break-system-packages"; \
    fi; \
    pip3 install --no-cache-dir $PIP_FLAGS "kas==${KAS_VERSION}"

RUN git config --system user.name "kas" \
 && git config --system user.email "kas@container" \
 && git config --system --add safe.directory '*'

RUN groupadd -g $GID $USERNAME \
 && useradd -m -u $UID -g $GID -s /bin/bash $USERNAME \
 && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
 && chmod 0440 /etc/sudoers.d/$USERNAME \
 && mkdir -p /workdir /downloads /sstate \
 && chown $UID:$GID /workdir /downloads /sstate

LABEL org.opencontainers.image.description="Yocto build environment (Ubuntu ${UBUNTU_VERSION}, kas ${KAS_VERSION})"

USER $USERNAME
WORKDIR /workdir
ENTRYPOINT ["/bin/bash"]