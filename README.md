# U-Boot for the Xiaomi 11 Lite 5G NE (lisa) — dual boot: postmarketOS + HakiOS

Mainline U-Boot built for the **Xiaomi 11 Lite 5G NE** (`lisa`, Snapdragon 778G / **SM7325**), with a
boot menu that starts either **postmarketOS** or the **HakiOS** loader (XNU/Darwin from RAM). The phone's
ABL starts this U-Boot from the `boot` partition like an Android kernel; nothing else on the phone is
touched on the way.

## The boot menu

At every power-on U-Boot shows a menu for 5 seconds (hold **Volume Down** while it starts to open the menu
without the countdown; **Volume Up/Down** move, **Power** selects):

| Entry | What |
|---|---|
| **postmarketOS** | boots pmOS from its image inside `userdata` (blkmap maps userdata as a disk, `sysboot` reads the image's `extlinux.conf`) |
| **HakiOS** | starts the HakiOS loader from the boot image's ramdisk, or waits for the host over fastboot |
| **HakiOS over fastboot** | the loader, waiting for `fastboot stage x.hkub` + `fastboot oem run:hakios load fastboot` + `fastboot continue` |
| **Enable serial console gadget** | USB ACM console |
| **Enable fastboot mode** | the fastboot screen |
| **What is in memory** / **Board info** / **Reset** / **Drop to shell** | diagnostics |

The default entry and countdown are set in the `bootcmd` line of
[`board/qualcomm/hakios-lisa.env`](board/qualcomm/hakios-lisa.env):

```
bootcmd=setenv bootmenu_default 1; bootmenu 5; run menucmd
```

`bootmenu_default` is the entry chosen when the countdown ends: **0 = postmarketOS**, **1 = HakiOS**.
Change it and rebuild to pick the silent default; Volume Down always reaches the menu either way.

## Files

| Path | What |
|---|---|
| `configs/hakios_lisa_defconfig` | the U-Boot defconfig (includes `qcom_defconfig`; SM7325 device tree, the HakiOS loader command, multiboot: BLKMAP + CMD_SYSBOOT, the fastboot/console knobs) |
| `board/qualcomm/hakios-lisa.env` | the boot environment: the menu, the pmOS boot (blkmap + sysboot), the HakiOS loader from memory or fastboot |
| `dts/upstream/src/arm64/qcom/sm7325-xiaomi-lisa.dts` | the device tree U-Boot builds against |
| `drivers/video/u_boot_logo.bmp`, `fastboot_logo.bmp` | the boot/fastboot splash |

These files go into a mainline U-Boot checkout (`configs/`, `board/qualcomm/`, `dts/upstream/src/arm64/qcom/`,
`drivers/video/`), then `make hakios_lisa_defconfig && make`.

## Build

```sh
# a mainline U-Boot tree with Qualcomm SM7325 support; drop these files in, then:
export CROSS_COMPILE=aarch64-linux-gnu-
make hakios_lisa_defconfig
make -j"$(nproc)"
# the output is u-boot.bin (an AArch64 image with a Linux header; ABL starts it like a kernel)
```

## Flash (Android boot image, header v3)

lisa's ABL wants a header-v3 Android boot image whose kernel is `gzip(u-boot.bin)` and whose ramdisk is empty:

```sh
gzip -9 -c u-boot.bin > u-boot.bin.gz
# mkbootimg (any recent one): header v3, kernel = the gzip, no ramdisk
mkbootimg --header_version 3 --kernel u-boot.bin.gz --os_version 0 --pagesize 4096 -o boot.img
fastboot flash boot_a boot.img    # or write boot_a directly from postmarketOS with dd
fastboot reboot
```

The HakiOS loader lives in `vendor_boot` (its vendor ramdisk is an HKUB container with the loader and a
USB-wait payload); the pmOS image and its device tree live in `userdata`. This U-Boot writes nothing to
storage on the way — no capsule updates, no env saved to flash.

## Notes

- The panic stays on the screen (`CONFIG_PANIC_HANG`), so a failed boot is readable.
- The watchdog U-Boot would start is left off: the HakiOS loader runs its own while XNU is up.
- Same SoC as the POCO X5 Pro (redwood), so the only device-specific parts are the device tree and this
  environment file.
