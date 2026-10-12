#!/bin/bash
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/home/q/.Xauthority}"

until xrandr >/dev/null 2>&1; do sleep 0.1; done

if ! xrandr 2>/dev/null | grep -q "240x280"; then
    xrandr --newmode 240x280 5.0 240 250 260 270 280 283 287 293 2>/dev/null || true
    xrandr --addmode HDMI-1 240x280 2>/dev/null || true
fi

xrandr --output HDMI-1 --mode 240x280 --panning 240x280+0+0 --dpi 60 2>/dev/null || true
xset s off -dpms 2>/dev/null || true
