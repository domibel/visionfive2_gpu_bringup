#!/bin/bash
# run_sway_jellyfish.sh — launch sway and run the jellyfish GPU demo on
# this board.
#
# Must be run from a real console/TTY, not a terminal inside an existing
# X11 or Wayland desktop session: a stray DISPLAY/WAYLAND_DISPLAY makes
# wlroots nest sway inside that session instead of using DRM/KMS directly,
# which fails outright or hits an unrelated GPU/Vulkan device-matching bug.
set -e

LOG=/tmp/run_sway_$(date +%Y%m%d-%H%M%S).log
exec > >(tee "$LOG") 2>&1
echo "== log: $LOG =="

if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
	echo "ERROR: DISPLAY or WAYLAND_DISPLAY is already set in this shell:"
	echo "  DISPLAY='$DISPLAY' WAYLAND_DISPLAY='$WAYLAND_DISPLAY'"
	echo
	echo "That means this shell is running inside an existing graphical"
	echo "session (X11 or Wayland). Run this from a real console/TTY instead,"
	echo "or first: unset DISPLAY WAYLAND_DISPLAY"
	exit 1
fi

# Ask for the sudo password once, up front, so none of the several sudo
# calls below (some inside a background process) hit a surprise prompt.
# (Deliberately `sudo true`, not `sudo -v` — on sudoers configs with both
# a password-required and a NOPASSWD rule for the same user, `-v`'s
# validate-only mode can ask for a password even when running an actual
# command wouldn't.)
sudo true

# Authoritative, kernel-level signal for "who currently holds DRM master
# on the display device" — not a log-text guess. The DC8200 display
# device's debugfs node lists every open DRM fd with a master y/n column.
DRI_CLIENTS=/sys/kernel/debug/dri/29400000.display/clients
master_holder() {
	sudo awk 'NR>1 && $4=="y" {print $1" (pid "$2")"}' "$DRI_CLIENTS" 2>/dev/null
}

HOLDER=$(master_holder)
if [ -n "$HOLDER" ]; then
	echo "ERROR: another process already holds the display (DRM master):"
	echo "  $HOLDER"
	echo "Only one compositor/display-server can own the display at a time."
	echo "Stop it first, e.g.: sudo kill <pid>"
	exit 1
fi

SWAY_PID=""
cleanup() {
	if [ -n "$SWAY_PID" ]; then
		sudo kill "$SWAY_PID" 2>/dev/null || true
	fi
}
trap cleanup EXIT

echo "== launching sway =="
sudo env XDG_RUNTIME_DIR=/run/user/0 XDG_SEAT=seat0 \
  WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 \
  PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 MESA_VK_DEVICE_SELECT=1010:36054182 \
  sway &
SWAY_PID=$!

WD=""
for i in 1 2 3 4 5 6 7 8 9 10; do
	sleep 1
	WD=$(basename "$(sudo sh -c 'ls -t /run/user/0/wayland-*.lock' 2>/dev/null | head -1)" .lock)
	[ -n "$WD" ] && break
done

if [ -z "$WD" ]; then
	echo "ERROR: sway did not start (no wayland-N socket appeared)."
	exit 1
fi

# A socket existing isn't proof sway actually got the display: if another
# process already holds DRM master, sway can still create its Wayland
# socket while being non-functional underneath. Confirm it's really us.
HOLDER=$(master_holder)
if [ -z "$HOLDER" ] || ! echo "$HOLDER" | grep -q "sway"; then
	echo "ERROR: sway created a socket but never acquired DRM master —"
	echo "it is not actually driving the display. Current holder: ${HOLDER:-none}"
	exit 1
fi
echo "sway is up, WAYLAND_DISPLAY=$WD"

echo "== sway's actual environment =="
REAL_SWAY_PID=$(pgrep -x sway | head -1)
sudo sh -c "cat /proc/$REAL_SWAY_PID/environ" | tr '\0' '\n' | grep -E 'WLR_|PVR_|MESA_|XDG_|WAYLAND_DISPLAY|DISPLAY'

echo "== running jellyfish =="
sudo env XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY="$WD" \
  PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 MESA_VK_DEVICE_SELECT=1010:36054182 \
  glmark2-es2-wayland -b jellyfish:duration=20

echo "== done, closing sway =="
