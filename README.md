# JH7110 / VisionFive 2 — PowerVR BXE-4-32 GPU + DC8200 display bring-up

![glmark2 jellyfish running under labwc, with one terminal showing the command and output and a second running fastfetch](labwc_glmark2_fastfetch_t30s.png)

## Summary

With a few small kernel changes you can get experimental GPU 3D graphics working
on the StarFive VisionFive 2.

### vkmark test results

The following results are from vkmark under three configurations: direct KMS
scanout (no compositor, no window) and two Wayland compositors, labwc and
Weston. The physical screen always runs at its native 1920x1080.

`vkmark` itself is tested windowed at 1920x1080 and 800x600:

| Scene | FPS (KMS, 1920x1080) | FPS (labwc, 1920x1080) | FPS (labwc, 800x600) | FPS (Weston, 800x600) |
|---|---|---|---|---|
| clear | 480 | 55 | 186 | 206 |
| cube | 140 | 34 | 131 | 134 |
| shading | 84 | 28 | 70 | 60 |
| desktop | 19 | 8 | 39 | 30 |
| effect2d | 9 | 5 | 21 | 21 |
| texture | 78 | 25 | 94 | 81 |
| vertex | 124 | 34 | 97 | 81 |

Command line invocation and output, e.g.:

- [`vkmark_7scenes_kms_mesa26.2.2-2_1920x1080_20sec_output.txt`](vkmark_7scenes_kms_mesa26.2.2-2_1920x1080_20sec_output.txt)
- [`vkmark_7scenes_labwc_mesa26.2.2-2_1920x1080_20sec_output.txt`](vkmark_7scenes_labwc_mesa26.2.2-2_1920x1080_20sec_output.txt)
- [`vkmark_7scenes_labwc_mesa26.2.2-2_800x600_20sec_output.txt`](vkmark_7scenes_labwc_mesa26.2.2-2_800x600_20sec_output.txt)
- [`vkmark_7scenes_weston_mesa26.2.2-2_800x600_20sec_output.txt`](vkmark_7scenes_weston_mesa26.2.2-2_800x600_20sec_output.txt)


### glmark2-es2-wayland test results

The following results are from glmark2-es2-wayland (OpenGL ES via Zink) under
two Wayland compositors, Weston and labwc. The physical screen always runs at
its native 1920x1080.

`glmark2` itself is tested windowed at 1920x1080 and 800x600:

| Scene | FPS (Weston, 1920x1080) | FPS (labwc, 1920x1080) | FPS (Weston, 800x600) | FPS (labwc, 800x600) |
|---|---|---|---|---|
| clear | 21 | 26 | 56 | 63 |
| shading | 16 | 18 | 45 | 40 |
| bump | 17 | 20 | 47 | 53 |
| function | 11 | 13 | 41 | 40 |
| texture | 15 | 18 | 47 | 52 |
| ideas | 7 | 11 | 16 | 13 |
| shadow | 5 | 5 | 15 | 13 |
| pulsar | 9 | 12 | 33 | 37 |
| refract | 3 | 3 | 4 | 4 |
| conditionals | 10 | 16 | 39 | 40 |
| effect2d | 6 | 10 | 37 | 38 |
| loop | 9 | 14 | 31 | 35 |
| buffer | 7 | 9 | 16 | 20 |
| desktop | 3 | 3 | 8 | 9 |
| terrain | 1 | 1 | 2 | 2 |
| build | 20 | 22 | 47 | 57 |
| jellyfish | 4 | 5 | 13 | 14 |


Command line invocation and output, e.g.:

- [`glmark2_jellyfish_weston_zink_mesa26.2.2-2_800x600_20sec_output.txt`](glmark2_jellyfish_weston_zink_mesa26.2.2-2_800x600_20sec_output.txt)
- [`glmark2_jellyfish_labwc_zink_mesa26.2.2-2_800x600_20sec_output.txt`](glmark2_jellyfish_labwc_zink_mesa26.2.2-2_800x600_20sec_output.txt)

glxgears under Weston with XWayland didn't work at all.

## Hardware

- StarFive VisionFive 2 (SoC: JH7110)
- GPU: Imagination PowerVR BXE-4-32 (BVNC `36.50.54.182`)

## Firmware

The driver loads `rogue_36.50.54.182_v1.fw` from `/lib/firmware/powervr/`.
Pinned to commit `8a58f818` (`FW version v1.1 (build 6976702 OS)`).

Install:

```bash
wget https://gitlab.freedesktop.org/imagination/linux-firmware/-/raw/8a58f81883f7be458daa34e418cc4079f995b279/powervr/rogue_36.50.54.182_v1.fw

sudo mkdir -p /lib/firmware/powervr
sudo cp rogue_36.50.54.182_v1.fw /lib/firmware/powervr/
```

## Kernel

You need to apply 2 branches to your kernel:

[`jh7110_dc8200_hdmi_v7.3-rc4`](https://github.com/domibel/linux/tree/jh7110_dc8200_hdmi_v7.3-rc4)
and
[`powervr_on_jh7110_visionfive2_v7.3-rc4`](https://github.com/domibel/linux/tree/powervr_on_jh7110_visionfive2_v7.3-rc4)

```bash
git remote add domibel https://github.com/domibel/linux
git fetch domibel powervr_on_jh7110_visionfive2_v7.3-rc4 jh7110_dc8200_hdmi_v7.3-rc4
git checkout -b test_gpu v7.3-rc4
git merge domibel/powervr_on_jh7110_visionfive2_v7.3-rc4
git merge domibel/jh7110_dc8200_hdmi_v7.3-rc4
```

and additionally, the following configs:

```
CONFIG_DRM_POWERVR=m
CONFIG_DRM_VERISILICON_DC=y
CONFIG_CMA=y
CONFIG_ERRATA_SIFIVE=y
CONFIG_ERRATA_SIFIVE_XPBMTUC=y
```


The DTB
`arch/riscv/boot/dts/starfive/jh7110-starfive-visionfive-2-v1.3b.dtb` is
built from the same tree; where it needs to go depends on how your board's
bootloader is set up, on my system it's `/boot/efi/dtb/starfive/`.

If your kernel's default CMA reservation is too small, increase it with
`cma=64M` or higher on your kernel cmdline.

## Install userspace packages

```bash
sudo apt install mesa-vulkan-drivers vulkan-tools vkmark glmark2-es2-wayland
```


## Loading the driver

The shader-cluster power domain ("rascal/dust") comes up gated after reset.
So you need to load the driver twice with different parameter values
(`pow_rascaldust_enable` defaults to `0`).

```bash
sudo insmod powervr.ko pow_rascaldust_enable=1
# a real dispatch here is what makes the FW actually ungate the domain
PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 vkmark --winsys headless -s 64x64 -b clear:duration=1
sudo rmmod powervr
sudo insmod powervr.ko
```


## Run vkmark  (with winsys backends kms or headless)


All the commands below set `MESA_VK_DEVICE_SELECT=1010:36054182`,
that is `vendorID:deviceID`,
`36054182` is derived from the BXE-4-32's BVNC (`36.50.54.182`)

```bash
export PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 MESA_VK_DEVICE_SELECT=1010:36054182

# headless - no root needed
vkmark --winsys headless -s 1920x1080 \
  -b clear:duration=20 -b cube:duration=20 -b shading:duration=20 \
  -b desktop:duration=20 -b effect2d:duration=20 -b texture:duration=20 \
  -b vertex:duration=20

# kms - needs root
# Stop your display manager first, e.g.
# `sudo systemctl stop lightdm`)
sudo env PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 MESA_VK_DEVICE_SELECT=1010:36054182 \
vkmark --winsys kms --winsys-options kms-tty=/dev/tty1 -s 1920x1080 \
  -b clear:duration=20 -b cube:duration=20 -b shading:duration=20 \
  -b desktop:duration=20 -b effect2d:duration=20 -b texture:duration=20 \
  -b vertex:duration=20
```

Sometimes this fails with `ErrorOutOfDeviceMemory`, especially if you run the scenes independently, e.g
```
vkmark ...  -b clear:duration=20
vkmark ...  -b cube:duration=20
vkmark ...  -b shading:duration=20
```


## Run under labwc (Wayland compositor)

```bash
sudo env XDG_RUNTIME_DIR=/run/user/0 XDG_SEAT=seat0 \
  WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 \
  labwc
```

```bash
sudo env XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0 \
  PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 MESA_VK_DEVICE_SELECT=1010:36054182 \
  glmark2-es2-wayland -b jellyfish:duration=20
```


## Run under Weston (Wayland compositor)

```bash
sudo env XDG_RUNTIME_DIR=/run/user/0 XDG_SEAT=seat0 \
  weston --backend=drm-backend.so --renderer=gl
```

```bash
sudo env XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-1 \
  PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 MESA_VK_DEVICE_SELECT=1010:36054182 \
  glmark2-es2-wayland -b jellyfish:duration=20
```

It is not always `wayland-1`, sometimes it is `wayland-0`.

## Issues

The rascal/dust power sequencing needs to be looked at.
