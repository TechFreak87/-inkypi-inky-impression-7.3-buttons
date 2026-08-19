#!/bin/sh
set -eu

PROJECT_DIR="/usr/local/inkypi"
SRC_DIR="$PROJECT_DIR/src"
VENV_DIR="$PROJECT_DIR/venv_inkypi"

BUTTON_SOURCE="./button_control.py"
BUTTON_TARGET="$PROJECT_DIR/button_control.py"

SERVICE_SOURCE="./systemd/inkypi-buttons.service"
SERVICE_TARGET="/etc/systemd/system/inkypi-buttons.service"

PATCH_FILE="./inkypi-plugin-endpoints.patch"

STANDBY_SOURCE="./assets/inkypi-shutdown-screen-800x480.png"
STANDBY_DIR="$PROJECT_DIR/assets"
STANDBY_TARGET="$STANDBY_DIR/inkypi-shutdown-screen-800x480.png"

PLUGIN_FILE="$SRC_DIR/blueprints/plugin.py"

echo "========================================"
echo " InkyPi Inky Impression 7.3 Buttons"
echo " Installer"
echo "========================================"
echo

if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte mit sudo ausführen:"
    echo
    echo "  sudo ./install.sh"
    echo
    exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "FEHLER: InkyPi wurde nicht unter $PROJECT_DIR gefunden."
    exit 1
fi

if [ ! -f "$PLUGIN_FILE" ]; then
    echo "FEHLER: $PLUGIN_FILE wurde nicht gefunden."
    exit 1
fi

if [ ! -x "$VENV_DIR/bin/python" ]; then
    echo "FEHLER: InkyPi Python-Venv wurde nicht gefunden:"
    echo "$VENV_DIR"
    exit 1
fi

if [ ! -f "$BUTTON_SOURCE" ]; then
    echo "FEHLER: $BUTTON_SOURCE fehlt."
    exit 1
fi

if [ ! -f "$SERVICE_SOURCE" ]; then
    echo "FEHLER: $SERVICE_SOURCE fehlt."
    exit 1
fi

if [ ! -f "$PATCH_FILE" ]; then
    echo "FEHLER: $PATCH_FILE fehlt."
    exit 1
fi

if [ ! -f "$STANDBY_SOURCE" ]; then
    echo "FEHLER: $STANDBY_SOURCE fehlt."
    exit 1
fi


echo "[1/9] Python-Abhängigkeiten installieren..."
"$VENV_DIR/bin/pip" install gpiozero lgpio

echo
echo "[2/9] Pimoroni Inky 2.4.0 sicherstellen..."

"$VENV_DIR/bin/pip" install --upgrade "inky==2.4.0"

E673_DRIVER=$(
    "$VENV_DIR/bin/python" - <<'PY2'
import inspect
import inky.inky_e673

print(inspect.getfile(inky.inky_e673))
PY2
)

if [ ! -f "$E673_DRIVER" ]; then
    echo "FEHLER: E673-Treiber wurde nicht gefunden:"
    echo "$E673_DRIVER"
    exit 1
fi

echo "E673-Treiber:"
echo "$E673_DRIVER"

echo "Optimiere E673 Command Timing auf 0.05s..."

"$VENV_DIR/bin/python" - "$E673_DRIVER" <<'PY2'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

old = """        self._gpio.set_value(self.dc_pin, Value.INACTIVE)
        time.sleep(0.3)
        self._spi_bus.xfer3([command])"""

new = """        self._gpio.set_value(self.dc_pin, Value.INACTIVE)
        time.sleep(0.05)
        self._spi_bus.xfer3([command])"""

if old in text:
    text = text.replace(old, new, 1)
elif "time.sleep(0.05)" in text:
    pass
else:
    raise SystemExit(
        "E673 Timing-Stelle nicht erkannt. Keine Aenderung vorgenommen."
    )

path.write_text(text)
PY2

echo
echo "[3/9] Button-Steuerung installieren..."

if [ -f "$BUTTON_TARGET" ]; then
    cp "$BUTTON_TARGET" "$BUTTON_TARGET.bak"
    echo "Backup erstellt: $BUTTON_TARGET.bak"
fi

cp "$BUTTON_SOURCE" "$BUTTON_TARGET"
chmod +x "$BUTTON_TARGET"

echo
echo "[4/9] Standby-Bild installieren..."

mkdir -p "$STANDBY_DIR"
cp "$STANDBY_SOURCE" "$STANDBY_TARGET"
chmod 644 "$STANDBY_TARGET"

echo "Standby-Bild installiert:"
echo "$STANDBY_TARGET"

echo
echo "[5/9] InkyPi-Endpunkte prüfen..."

if grep -q "display_plugin_cached" "$PLUGIN_FILE" &&
   grep -q "shutdown_screen" "$PLUGIN_FILE"; then
    echo "Patch ist bereits vorhanden. Überspringe Patch-Schritt."
else
    echo "Erstelle Backup von plugin.py..."
    cp "$PLUGIN_FILE" "$PLUGIN_FILE.bak"

    echo "Wende Patch an..."

    cd "$PROJECT_DIR"

    if patch -p1 --dry-run < "$OLDPWD/$PATCH_FILE" >/dev/null 2>&1; then
        patch -p1 < "$OLDPWD/$PATCH_FILE"
    else
        echo "FEHLER: Patch konnte nicht sauber angewendet werden."
        echo
        echo "Keine Änderung an plugin.py durchgeführt."
        echo "Backup liegt unter:"
        echo "$PLUGIN_FILE.bak"
        exit 1
    fi

    cd "$OLDPWD"
fi

echo
echo "[6/9] Python-Syntax prüfen..."

"$VENV_DIR/bin/python" -m py_compile "$BUTTON_TARGET"
"$VENV_DIR/bin/python" -m py_compile "$PLUGIN_FILE"

echo
echo "[7/9] systemd-Service installieren..."

cp "$SERVICE_SOURCE" "$SERVICE_TARGET"

systemctl daemon-reload
systemctl enable inkypi-buttons.service

echo
echo "[8/9] InkyPi neu starten..."

systemctl restart inkypi.service

echo "Warte auf InkyPi..."
sleep 20

echo
echo "[9/9] Button-Service starten..."

systemctl restart inkypi-buttons.service

echo
echo "========================================"
echo " Installation abgeschlossen"
echo "========================================"
echo

echo "InkyPi:"
systemctl is-active inkypi.service || true

echo
echo "Button-Service:"
systemctl is-active inkypi-buttons.service || true

echo
echo "Button-Belegung:"
echo "  A kurz     = vorherige Seite"
echo "  B kurz     = nächste Seite"
echo "  C/D kurz   = keine Funktion"
echo "  A/B/C/D 3s = Shutdown"
echo
echo "Normaler InkyPi-Playlistbetrieb bleibt aktiv."
echo
