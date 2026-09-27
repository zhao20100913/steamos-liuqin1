#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/.." && pwd)"
KZIP="${1:?Usage: $0 /path/to/linux-sm8450-liuqin-liuqin-6.17.zip}"
[[ -f "$KZIP" ]] || { echo "Kernel zip not found: $KZIP" >&2; exit 1; }
command -v unzip >/dev/null || { echo 'Install unzip first' >&2; exit 1; }
command -v make >/dev/null || { echo 'Install build-essential/gcc first' >&2; exit 1; }
if ! command -v aarch64-linux-gnu-gcc >/dev/null; then
  echo 'aarch64-linux-gnu-gcc is required; install gcc-aarch64-linux-gnu.' >&2
  exit 1
fi

WORK="${WORK:-$PROJ/work}"
OUT="$PROJ/out"
KDIR="$WORK/kernel"
rm -rf "$KDIR" "$OUT"
mkdir -p "$WORK" "$OUT"
unzip -q "$KZIP" -d "$KDIR"
KROOT="$(find "$KDIR" -maxdepth 2 -type f -name Makefile -printf '%h\n' | head -n1)"
[[ -n "$KROOT" ]] || { echo 'Could not locate kernel source' >&2; exit 1; }

cd "$KROOT"
make ARCH=arm64 sm8450.config
make -j"$(nproc)" ARCH=arm64 Image.gz dtbs modules
make -j"$(nproc)" ARCH=arm64 modules_install INSTALL_MOD_PATH="$OUT/modules"
mkdir -p "$OUT/boot-files"
cp arch/arm64/boot/Image.gz "$OUT/boot-files/"
cp arch/arm64/boot/dts/qcom/sm8475-xiaomi-liuqin.dtb "$OUT/boot-files/"
cp .config "$OUT/boot-files/kernel.config"

# The Steam Frame downloader is intentionally run after kernel compilation.
chmod +x "$PROJ"/scripts/host/*.sh "$PROJ"/scripts/in-chroot/*.sh
sudo env WORK="$WORK/frame-work" OUT="$WORK/frame-work/out" bash "$PROJ/scripts/host/00-fetch-frame-rootfs.sh"
sudo bash "$PROJ/scripts/host/01-lay-rootfs.sh" "$WORK/frame-work/out/rootfs.frame" "$OUT/rootfs.img" "${ROOTFS_SIZE:-8G}"

sudo mkdir -p /mnt/rootfs
sudo mount -o loop "$OUT/rootfs.img" /mnt/rootfs
cleanup(){ sudo umount -R /mnt/rootfs 2>/dev/null || true; }
trap cleanup EXIT
sudo rm -rf /mnt/rootfs/boot/* /mnt/rootfs/usr/lib/modules/* 2>/dev/null || true
sudo mkdir -p /mnt/rootfs/boot /mnt/rootfs/usr/lib/modules
sudo cp -a "$OUT/boot-files/Image.gz" "$OUT/boot-files/sm8475-xiaomi-liuqin.dtb" /mnt/rootfs/boot/
sudo cp -a "$OUT/modules/lib/modules/." /mnt/rootfs/usr/lib/modules/ 2>/dev/null || true
if [[ -n "${LIUQIN_FIRMWARE_DIR:-}" && -d "$LIUQIN_FIRMWARE_DIR" ]]; then
  sudo mkdir -p /mnt/rootfs/lib/firmware
  sudo cp -a "$LIUQIN_FIRMWARE_DIR/." /mnt/rootfs/lib/firmware/
fi
for d in dev dev/pts proc sys; do sudo mkdir -p "/mnt/rootfs/$d"; done
sudo mount --bind /dev /mnt/rootfs/dev
sudo mount --bind /dev/pts /mnt/rootfs/dev/pts || true
sudo mount -t proc proc /mnt/rootfs/proc
sudo mount -t sysfs sys /mnt/rootfs/sys
sudo rm -f /mnt/rootfs/etc/resolv.conf
sudo cp /etc/resolv.conf /mnt/rootfs/etc/resolv.conf || true
sudo cp "$PROJ/scripts/in-chroot/10-graft.sh" /mnt/rootfs/root/10-graft.sh
sudo chmod +x /mnt/rootfs/root/10-graft.sh
if [[ "$(uname -m)" != "aarch64" && -x /usr/bin/qemu-aarch64-static ]]; then
  sudo cp -f /usr/bin/qemu-aarch64-static /mnt/rootfs/usr/bin/
fi
sudo chroot /mnt/rootfs env PARTLABEL="${PARTLABEL:-linux}" /root/10-graft.sh
sudo rm -f /mnt/rootfs/root/10-graft.sh
sudo sync
cleanup; trap - EXIT
sudo env SHRINK_IMAGE=true bash "$PROJ/scripts/host/03-finalize-image.sh" "$OUT/rootfs.img" /mnt/rootfs

echo
printf 'Build complete:\n  %s\n  %s\n' "$OUT/rootfs.img" "$OUT/boot-files/"
