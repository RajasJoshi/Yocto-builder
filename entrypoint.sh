#!/bin/sh
# Started as root with YOCTO_UID/YOCTO_GID: remap the 'yocto' user to the
# host user's uid/gid so bind mounts are writable and ssh/sudo can resolve the
# user, then drop privileges. bitbake refuses to run as root, so root never
# gets a shell here. Started as non-root (plain `docker run`): exec bash as-is.
set -eu

USERNAME=yocto

if [ "$(id -u)" -ne 0 ]; then
  exec /bin/bash "$@"
fi

uid="${YOCTO_UID:-$(id -u $USERNAME)}"
gid="${YOCTO_GID:-$(id -g $USERNAME)}"

if [ "$uid" -eq 0 ] || [ "$gid" -eq 0 ]; then
  echo "entrypoint: refusing to run as root (bitbake does not allow it)" >&2
  exit 1
fi

old_uid="$(id -u $USERNAME)"
old_gid="$(id -g $USERNAME)"

if [ "$gid" != "$old_gid" ]; then
  if getent group "$gid" >/dev/null; then
    # GID already taken by another group in the image: join that one instead.
    usermod -g "$gid" $USERNAME
  else
    groupmod -g "$gid" $USERNAME
  fi
fi

if [ "$uid" != "$old_uid" ]; then
  # Another image account (e.g. nobody=65534) already has this uid: move it to
  # a free uid so lookups by uid resolve to yocto, not to that account.
  other="$(getent passwd "$uid" | cut -d: -f1)"
  if [ -n "$other" ] && [ "$other" != "$USERNAME" ]; then
    free="$(awk -F: '{u[$3]=1} END {for (i = 60000; i < 65000; i++) if (!(i in u)) {print i; exit}}' /etc/passwd)"
    usermod -u "$free" "$other" 2>/dev/null || true
    [ "$(id -u "$other")" = "$free" ] || { echo "entrypoint: uid $uid is taken by $other" >&2; exit 1; }
  fi
  # usermod also chowns the home tree and can fail on read-only bind mounts
  # inside it (~/.ssh); the passwd entry is written first, so verify that.
  usermod -o -u "$uid" $USERNAME 2>/dev/null || true
  [ "$(id -u $USERNAME)" = "$uid" ] || { echo "entrypoint: failed to set uid $uid" >&2; exit 1; }
fi

# Fix ownership of the image's own files only. -xdev stops descent into bind
# mounts but still visits the mount point itself, so prune the read-only ~/.ssh.
find /home/$USERNAME -xdev -path "/home/$USERNAME/.ssh" -prune -o \
  \( -uid "$old_uid" -o -gid "$old_gid" \) -exec chown -h "$uid:$gid" {} +

export HOME=/home/$USERNAME USER=$USERNAME LOGNAME=$USERNAME
exec setpriv --reuid="$uid" --regid="$gid" --init-groups /bin/bash "$@"
