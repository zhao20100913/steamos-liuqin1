#!/usr/bin/env bash
# Inject the liuqin device layer into a Steam Frame-derived rootfs.
set -euo pipefail
log(){ printf '[%s] %s\n' "${0##*/}" "$*"; }
warn(){ printf '[%s] WARNING: %s\n' "${0##*/}" "$*" >&2; }
die(){ printf '[%s] ERROR: %s\n' "${0##*/}" "$*" >&2; exit 1; }

PARTLABEL="${PARTLABEL:-linux}"
KVER="${KVER:-}"

for c in /sbin/init /usr/sbin/init /usr/lib/systemd/systemd; do
  [[ -x "$c" ]] && INIT="$c" && break
done
[[ -x "${INIT:-}" ]] || die "No systemd init found"

# Remove Frame kernels. The liuqin kernel is installed by the host build step.
mapfile -t kp < <(pacman -Qq 2>/dev/null | grep -E '^linux(-[a-z0-9]+)?$' || true)
if ((${#kp[@]})); then
  pacman -Rdd --noconfirm --color never "${kp[@]}" || warn "could not remove Frame kernel packages"
fi

# Avoid signature problems for locally-built packages.
if [[ -f /etc/pacman.conf ]]; then
  sed -i 's/^[[:space:]]*LocalFileSigLevel.*/LocalFileSigLevel = Optional/' /etc/pacman.conf
  grep -q '^LocalFileSigLevel' /etc/pacman.conf || sed -i '/^\[options\]/a LocalFileSigLevel = Optional' /etc/pacman.conf
fi

# Optional local package drop-in.
shopt -s nullglob
pkgs=(/tmp/pkgs/*.pkg.tar.*)
if ((${#pkgs[@]})); then
  log "Installing ${#pkgs[@]} local device packages"
  pacman -U --noconfirm --color never --nodeps --overwrite '*' "${pkgs[@]}" || die "device package installation failed"
fi

# Kernel modules must already have been installed by the host step.
if [[ -d /usr/lib/modules ]]; then
  for d in /usr/lib/modules/*; do
    [[ -d "$d" ]] || continue
    depmod -a "$(basename "$d")" || warn "depmod failed for $(basename "$d")"
  done
fi

cat > /etc/fstab <<FSTAB
# SteamOS for Xiaomi Pad 6 Pro (liuqin)
# The bootloader/partition layout must provide this PARTLABEL.
PARTLABEL=$PARTLABEL / ext4 defaults,x-systemd.growfs 0 1
FSTAB

: > /etc/machine-id
printf '%s\n' 'liuqin' > /etc/hostname
ln -sf /usr/share/zoneinfo/UTC /etc/localtime 2>/dev/null || true

for d in var/lib/pacman var/lib/dbus var/lib/systemd var/lib/NetworkManager var/lib/iwd \
         var/log var/log/journal var/tmp var/cache var/cache/pacman/pkg home root srv mnt opt proc sys dev run tmp; do
  mkdir -p "/$d"
done
chmod 1777 /tmp /var/tmp 2>/dev/null || true
chmod 0700 /root 2>/dev/null || true

systemctl enable NetworkManager.service 2>/dev/null || warn "could not enable NetworkManager"
command -v sddm >/dev/null 2>&1 && systemctl enable sddm.service 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

log "liuqin device layer injected"
