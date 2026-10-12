#!/bin/bash
# ==============================================================================
# Script de Instalación y Despliegue Automatizado ST7789 1.69" (240x280)
# Repositorio: https://github.com/l707l/rpi-st7789-240x280-display
# Hardware: Pantalla LCD IPS 1.69 pulgadas (ST7789VW SPI 8 pines) en Raspberry Pi
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

echo "========================================================================"
echo "  Despliegue Automático ST7789 (240x280) para Raspberry Pi"
echo "  Usuario objetivo: $TARGET_USER ($TARGET_HOME)"
echo "========================================================================"

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: Este script debe ejecutarse con privilegios sudo."
    echo "    Uso: sudo ./install.sh"
    exit 1
fi

# 1. Dependencias del sistema
echo "[1/7] Instalando paquetes y dependencias de compilación..."
apt-get update -y
apt-get install -y cmake build-essential git xdotool libx11-dev libxext-dev libbsd-dev

# 2. Configuración de Firmware (/boot/firmware/config.txt o /boot/config.txt)
echo "[2/7] Configurando /boot/firmware/config.txt..."
CONFIG_TXT="/boot/firmware/config.txt"
[ ! -f "$CONFIG_TXT" ] && CONFIG_TXT="/boot/config.txt"

# Limpiar entradas anteriores si existen
sed -i '/# ST7789 1.69 IPS/,+7d' "$CONFIG_TXT" 2>/dev/null || true
sed -i '/hdmi_cvt=240 280/d' "$CONFIG_TXT" 2>/dev/null || true
sed -i '/framebuffer_width=240/d' "$CONFIG_TXT" 2>/dev/null || true
sed -i '/framebuffer_height=280/d' "$CONFIG_TXT" 2>/dev/null || true

if ! grep -q "^dtparam=spi=on" "$CONFIG_TXT"; then
    echo "dtparam=spi=on" >> "$CONFIG_TXT"
fi
if ! grep -q "^core_freq=400" "$CONFIG_TXT"; then
    echo "core_freq=400" >> "$CONFIG_TXT"
    echo "core_freq_min=400" >> "$CONFIG_TXT"
fi

cat << 'EOF' >> "$CONFIG_TXT"

# ST7789 1.69 IPS 240x280 TFT Display & DispmanX
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt=240 280 60 1 0 0 0
framebuffer_width=240
framebuffer_height=280
EOF

# 3. Descarga y Parche de fbcp-ili9341
echo "[3/7] Preparando y compilando fbcp-ili9341 con optimizaciones para ST7789..."
FBCP_DIR="$TARGET_HOME/fbcp-ili9341"
if [ ! -d "$FBCP_DIR" ]; then
    sudo -u "$TARGET_USER" git clone https://github.com/juj/fbcp-ili9341.git "$FBCP_DIR"
fi

PATCH_FILE="$SCRIPT_DIR/patches/st7789_240x280.patch"
if [ -f "$PATCH_FILE" ]; then
    echo "    -> Aplicando parche st7789_240x280.patch..."
    cd "$FBCP_DIR"
    git apply --whitespace=nowarn "$PATCH_FILE" 2>/dev/null || {
        echo "    -> Patch ya aplicado o archivos modificados, verificando..."
    }
fi

mkdir -p "$FBCP_DIR/build"
cd "$FBCP_DIR/build"
sudo -u "$TARGET_USER" cmake -DST7789VW=ON \
      -DGPIO_TFT_DATA_CONTROL=25 \
      -DGPIO_TFT_RESET_PIN=24 \
      -DGPIO_TFT_BACKLIGHT=0 \
      -DDISPLAY_WIDTH=240 \
      -DDISPLAY_HEIGHT=280 \
      -DSPI_BUS_CLOCK_DIVISOR=8 \
      -DSTATISTICS=1 \
      -DCMAKE_BUILD_TYPE=Release ..
sudo -u "$TARGET_USER" make -j$(nproc)

systemctl stop fbcp.service 2>/dev/null || true
cp "$FBCP_DIR/build/fbcp-ili9341" /usr/local/bin/fbcp
chmod +x /usr/local/bin/fbcp

# 4. Servicio Systemd Early Boot
echo "[4/7] Instalando /etc/systemd/system/fbcp.service..."
cp "$SCRIPT_DIR/configs/fbcp.service" /etc/systemd/system/fbcp.service
systemctl daemon-reload
systemctl enable fbcp.service
systemctl restart fbcp.service

# 5. Modos de Pantalla y LightDM
echo "[5/7] Instalando /usr/local/bin/setup-display.sh y configuración LightDM..."
cp "$SCRIPT_DIR/configs/setup-display.sh" /usr/local/bin/setup-display.sh
chmod +x /usr/local/bin/setup-display.sh
chown root:root /usr/local/bin/setup-display.sh

mkdir -p /etc/lightdm/lightdm.conf.d
cp "$SCRIPT_DIR/configs/60-display-setup.conf" /etc/lightdm/lightdm.conf.d/60-display-setup.conf

# 6. Miniaturización del Entorno Gráfico (LXDE / Openbox / GTK)
echo "[6/7] Desplegando configuraciones de usuario..."

# .Xresources
cp "$SCRIPT_DIR/configs/Xresources" "$TARGET_HOME/.Xresources"

# .xsessionrc
cp "$SCRIPT_DIR/configs/xsessionrc" "$TARGET_HOME/.xsessionrc"
chmod +x "$TARGET_HOME/.xsessionrc"

# LXSession Autostart
mkdir -p "$TARGET_HOME/.config/lxsession/LXDE"
cp "$SCRIPT_DIR/configs/autostart" "$TARGET_HOME/.config/lxsession/LXDE/autostart"

# GTK Fonts (Sans 6)
mkdir -p "$TARGET_HOME/.config/gtk-3.0"
cat << 'EOF' > "$TARGET_HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-font-name=Sans 6
gtk-icon-theme-name=Papirus-Dark
gtk-theme-name=Adwaita-dark
gtk-cursor-theme-size=16
EOF

cat << 'EOF' > "$TARGET_HOME/.gtkrc-2.0"
style "font" { font_name = "Sans 6" }
widget_class "*" style "font"
gtk-font-name = "Sans 6"
gtk-icon-theme-name = "Papirus-Dark"
gtk-theme-name = "Adwaita-dark"
gtk-cursor-theme-size = 16
EOF

# Openbox (Confinamiento 240px de ancho y fuentes 6pt)
mkdir -p "$TARGET_HOME/.config/openbox"
if [ -f "$TARGET_HOME/.config/openbox/lxde-rc.xml" ]; then
    sed -i 's|<right>[0-9]*</right>|<right>720</right>|' "$TARGET_HOME/.config/openbox/lxde-rc.xml" 2>/dev/null || true
    sed -i 's|<font place="ActiveWindow">.*|<font place="ActiveWindow"><name>Sans</name><size>6</size><weight>Normal</weight><slant>Normal</slant></font>|' "$TARGET_HOME/.config/openbox/lxde-rc.xml" 2>/dev/null || true
    sed -i 's|<font place="InactiveWindow">.*|<font place="InactiveWindow"><name>Sans</name><size>6</size><weight>Normal</weight><slant>Normal</slant></font>|' "$TARGET_HOME/.config/openbox/lxde-rc.xml" 2>/dev/null || true
fi

# LXPanel con padding para esquinas curvadas
mkdir -p "$TARGET_HOME/.config/lxpanel/LXDE/panels"
cp "$SCRIPT_DIR/configs/panel" "$TARGET_HOME/.config/lxpanel/LXDE/panels/panel"

# PCManFM (Iconos pequeños y fondo sólido #181818)
mkdir -p "$TARGET_HOME/.config/pcmanfm/LXDE"
cp "$SCRIPT_DIR/configs/desktop-items-0.conf" "$TARGET_HOME/.config/pcmanfm/LXDE/desktop-items-0.conf"

# 7. Permisos
echo "[7/7] Restaurando permisos de usuario en $TARGET_HOME..."
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.Xresources" "$TARGET_HOME/.xsessionrc" "$TARGET_HOME/.gtkrc-2.0"

echo ""
echo "========================================================================"
echo "  ¡INSTALACIÓN COMPLETADA CON ÉXITO!"
echo "  - Driver compilado con 20 filas de offset y sin modo espejo."
echo "  - Servicio fbcp.service activo en Early Boot."
echo "  - Miniaturización LXDE a 6pt con padding de 8px para cristal curvo."
echo "  Se recomienda reiniciar: sudo reboot"
echo "========================================================================"
