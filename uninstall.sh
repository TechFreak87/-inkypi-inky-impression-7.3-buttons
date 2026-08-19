#!/bin/sh
set -eu

PROJECT_DIR="/usr/local/inkypi"
SRC_DIR="$PROJECT_DIR/src"

BUTTON_FILE="$PROJECT_DIR/button_control.py"
SERVICE_FILE="/etc/systemd/system/inkypi-buttons.service"

PLUGIN_FILE="$SRC_DIR/blueprints/plugin.py"
PLUGIN_BACKUP="$PLUGIN_FILE.bak"

echo "========================================"
echo " InkyPi Inky Impression 7.3 Buttons"
echo " Uninstaller"
echo "========================================"
echo

if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte mit sudo ausführen:"
    echo
    echo "  sudo ./uninstall.sh"
    echo
    exit 1
fi

echo "[1/5] Button-Service stoppen..."

systemctl stop inkypi-buttons.service 2>/dev/null || true
systemctl disable inkypi-buttons.service 2>/dev/null || true

echo
echo "[2/5] systemd-Service entfernen..."

if [ -f "$SERVICE_FILE" ]; then
    rm -f "$SERVICE_FILE"
fi

systemctl daemon-reload

echo
echo "[3/5] Button-Steuerung entfernen..."

if [ -f "$BUTTON_FILE" ]; then
    rm -f "$BUTTON_FILE"
fi

echo
echo "[4/5] InkyPi plugin.py wiederherstellen..."

if [ -f "$PLUGIN_BACKUP" ]; then
    cp "$PLUGIN_BACKUP" "$PLUGIN_FILE"
    echo "Backup wiederhergestellt:"
    echo "$PLUGIN_BACKUP"
else
    echo "Kein plugin.py-Backup gefunden."
    echo "Die zusätzlichen Endpunkte bleiben daher bestehen."
fi

echo
echo "[5/5] InkyPi neu starten..."

systemctl restart inkypi.service

echo
echo "========================================"
echo " Deinstallation abgeschlossen"
echo "========================================"
echo
