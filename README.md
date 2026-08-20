# JH7110 / VisionFive 2 — PowerVR BXE-4-32 GPU + DC8200 display bring-up

## Summary

With a few small kernel changes you can get experimental GPU 3D graphics working
on the StarFive VisionFive 2. The vkmark 1920x1080 test results look promising:

| Scene | FPS |
|---|---|
| clear | 54 |
| cube | 27 |
| shading | 25 |
| desktop | 12 |
| effect2d | 7 |
| texture | 25 |
| vertex | 26 |

Full raw output, including the exact command used:
[`vkmark_output.txt`](vkmark_output.txt),
[`vulkaninfo_output.txt`](vulkaninfo_output.txt).

## Hardware

- StarFive VisionFive 2 (SoC: JH7110)
- GPU: Imagination PowerVR BXE-4-32 (BVNC `36.50.54.182`)

## Firmware

The driver loads `rogue_36.50.54.182_v1.fw` from `/lib/firmware/powervr/`.
Pinned to commit `8a58f818` ("update to version 1.1.OS@6976702"), which
matches the FW version this board actually ran for the outputs in this
folder (`FW version v1.1 (build 6976702 OS)`).

Install:

```bash
wget https://gitlab.freedesktop.org/imagination/linux-firmware/-/raw/8a58f81883f7be458daa34e418cc4079f995b279/powervr/rogue_36.50.54.182_v1.fw

sudo mkdir -p /lib/firmware/powervr
sudo cp rogue_36.50.54.182_v1.fw /lib/firmware/powervr/
```

## Kernel

You need to apply 2 branches to your kernel:
[`jh7110_dc8200_hdmi_v7.2`](https://github.com/domibel/linux/tree/jh7110_dc8200_hdmi_v7.2)
and
[`powervr_on_jh7110_visionfive2_v7.2`](https://github.com/domibel/linux/tree/powervr_on_jh7110_visionfive2_v7.2)

```bash
git remote add domibel https://github.com/domibel/linux
git fetch domibel powervr_on_jh7110_visionfive2_v7.2 jh7110_dc8200_hdmi_v7.2
git checkout -b test_gpu v7.2
git merge domibel/powervr_on_jh7110_visionfive2_v7.2
git merge domibel/jh7110_dc8200_hdmi_v7.2
```

and additionally, the following configs:

```
CONFIG_DRM_POWERVR=m
CONFIG_DRM_VERISILICON_DC=y
CONFIG_CMA=y
```


The DTB
`arch/riscv/boot/dts/starfive/jh7110-starfive-visionfive-2-v1.3b.dtb` is
built from the same tree; where it needs to go depends on how your board's
bootloader is set up (on my system it's `/boot/efi/dtb/starfive/`).

If your kernel's default CMA reservation is too small, increase it with
`cma=64M` (or higher) on your kernel cmdline.

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


## Install userspace packages

```bash
sudo apt install mesa-vulkan-drivers vulkan-tools vkmark
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
`rmmod` also fails from time to time with a board hang.


## FW issues

I am not sure if these are FW bugs, but the rascal/dust power sequencing
and the missing completion IRQ need to be looked at.
