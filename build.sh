#!/usr/bin/env bash
# Build this U-Boot for lisa WITHOUT touching the shared tree research/hackios-xnu-kernel/u-boot: a private copy of
# it (HakiOS's U-Boot 2026.07 with cmd/hakios.c and the Qualcomm USB protocol) under darwin-lisa/.work/u-boot-ossel/src,
# these overlay files on top, and the boot image ABL wants (header v3, kernel = gzip(u-boot.bin), no ramdisk).
#
#   u-boot-lisa/build.sh [OUT.img]          default out/u-boot-lisa-ossel.img
#
# The .config it makes is identical to the one of the flashed U-Boot (u-boot/build-lisa/.config): only the
# environment (board/qualcomm/hakios-lisa.env) differs.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
M=$(dirname "$HERE")
SRC=$M/darwin-lisa/.work/u-boot-ossel/src
OUT=${1:-$M/out/u-boot-lisa-ossel.img}
export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}

if [[ ! -d $SRC ]]; then
	mkdir -p "$SRC"
	rsync -a --exclude='/build-*' --exclude='.git' "$M/research/hackios-xnu-kernel/u-boot/" "$SRC/"
fi
cp "$HERE/board/qualcomm/hakios-lisa.env" "$SRC/board/qualcomm/"
cp "$HERE/configs/hakios_lisa_defconfig" "$SRC/configs/"
cp "$HERE/dts/upstream/src/arm64/qcom/sm7325-xiaomi-lisa.dts" "$SRC/dts/upstream/src/arm64/qcom/"
cp "$HERE"/drivers/video/*.bmp "$SRC/drivers/video/"
make -C "$SRC" -s O=build-lisa hakios_lisa_defconfig
make -C "$SRC" -s O=build-lisa -j"$(nproc)"
gzip -9 -n -c "$SRC/build-lisa/u-boot.bin" >"$SRC/../u-boot.bin.gz"
python3 -I "$M/research/hackios-xnu-kernel/devices/lisa/prebuilt/mkbootimg.py" --header_version 3 \
	--kernel "$SRC/../u-boot.bin.gz" --os_version 0 --pagesize 4096 -o "$OUT"
sha256sum "$OUT"
