# SteamOS for Xiaomi Pad 6 Pro (liuqin)

This project adapts the Steam Frame ARM64 SteamOS userspace builder to the Xiaomi Pad 6 Pro (`liuqin`, Qualcomm SM8475).

## What this project does

- Uses the official Steam Frame ARM64 userspace as the base.
- Removes the Frame kernel from the target rootfs.
- Builds/installs the `liuqin` Linux 6.17 kernel and `sm8475-xiaomi-liuqin.dtb`.
- Installs a user-supplied liuqin firmware tree when provided.
- Writes a simple ext4 rootfs with `PARTLABEL=linux` by default.
- Does **not** reuse any ` liuqin` kernel, DTB, firmware, or boot image.

## Important

This is a build project, not a ready-to-flash image. The exact Xiaomi Pad 6 Pro boot image format/partition layout must be matched to the boot chain currently installed on the tablet. Do not flash an unknown `boot.img` or repartition the tablet from this project alone.

## Local build on Ubuntu/Debian ARM64

1. Put these files in the same directory:

   - `steamos-liuqin-mainline-20260927.zip`
   - `linux-sm8450-liuqin-liuqin-6.17.zip`

2. Extract this project and run:

```bash
sudo apt update
sudo apt install -y git curl bzip2 zstd xz-utils e2fsprogs rsync util-linux btrfs-progs python3 qemu-user-static binfmt-support
chmod +x scripts/host/*.sh scripts/in-chroot/*.sh
./scripts/build-liuqin-local.sh /path/to/linux-sm8450-liuqin-liuqin-6.17.zip
```

The script builds the kernel, creates `out/boot-files/`, and creates `out/rootfs.img` when the Steam Frame base can be downloaded.

## Firmware

The liuqin DTS references at least:

- `qcom/sm8475/liuqin/a730_zap.mbn`
- `qcom/sm8475/liuqin/adsp.mbn`
- `qcom/sm8475/liuqin/cdsp.mbn`
- `qcom/sm8475/liuqin/slpi.mbn`
- `novatek/liuqin/novatek_nt36532_m81_fw_csot.bin`

A firmware directory can be supplied with:

```bash
LIUQIN_FIRMWARE_DIR=/path/to/lib/firmware ./scripts/build-liuqin-local.sh kernel.zip
```

The builder will copy it into the rootfs and report missing referenced firmware. Do not substitute unrelated SM8450/SM8550 firmware.

## GitHub Actions

`.github/workflows/rootfs.yml` is prepared for ARM64 runners. It accepts the kernel repository/ref and optional firmware archive URL as workflow inputs. The defaults intentionally point at no guessed firmware repository.

## Current scope

Working base:

- liuqin-specific SM8475 DTS
- DRM/MSM + dual DSI + Novatek NT36532
- Adreno A730 kernel support
- SoundWire/WCD9380 kernel support
- ARM64 Steam Frame userspace

Still device-specific:

- exact firmware set
- boot image packing/header parameters
- final Xiaomi partition/slot integration
- Steam/Proton/FEX performance validation
