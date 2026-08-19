#!/usr/bin/env python3

import sys
import time
import requests
import subprocess
from datetime import datetime

import pytz
from gpiozero import Button

sys.path.insert(0, "/usr/local/inkypi/src")

from config import Config


BUTTONS = {
    "A": 5,
    "B": 6,
    "C": 16,
    "D": 24,
}

LONG_PRESS_SECONDS = 3.0
BASE_URL = "http://127.0.0.1"


press_started = {}
shutdown_started = False


def get_active_playlist():
    # Reload the configuration on every button action so playlist changes
    # made by the running InkyPi process are picked up immediately.
    device_config = Config()
    playlist_manager = device_config.get_playlist_manager()

    tz_str = device_config.get_config("timezone", default="UTC")
    now = datetime.now(pytz.timezone(tz_str))

    return playlist_manager.determine_active_playlist(now)


def display_plugin(playlist, plugin):
    payload = {
        "playlist_name": playlist.name,
        "plugin_id": plugin.plugin_id,
        "plugin_instance": plugin.name,
    }

    try:
        response = requests.post(
            f"{BASE_URL}/display_plugin_instance",
            json=payload,
            timeout=120,
        )

        response.raise_for_status()

        print(
            f"Anzeige neu erzeugt: {playlist.name} -> {plugin.name}",
            flush=True,
        )

    except requests.RequestException as exc:
        print(
            f"InkyPi nicht erreichbar oder Display-Update fehlgeschlagen: {exc}",
            flush=True,
        )


def previous_plugin():
    playlist = get_active_playlist()

    if not playlist or not playlist.plugins:
        print("Keine aktive Playlist.", flush=True)
        return

    current = playlist.current_plugin_index

    if current is None:
        current = 0

    new_index = (current - 1) % len(playlist.plugins)
    playlist.current_plugin_index = new_index

    display_plugin(
        playlist,
        playlist.plugins[new_index],
    )


def next_plugin():
    playlist = get_active_playlist()

    if not playlist or not playlist.plugins:
        print("Keine aktive Playlist.", flush=True)
        return

    current = playlist.current_plugin_index

    if current is None:
        current = -1

    new_index = (current + 1) % len(playlist.plugins)
    playlist.current_plugin_index = new_index

    display_plugin(
        playlist,
        playlist.plugins[new_index],
    )


def shutdown():
    global shutdown_started

    if shutdown_started:
        return

    shutdown_started = True

    print(
        "Langer Tastendruck erkannt. Shutdown wird gestartet.",
        flush=True,
    )

    try:
        response = requests.post(
            f"{BASE_URL}/shutdown_screen",
            timeout=120,
        )

        response.raise_for_status()

        print(
            "Shutdown-Bild wurde angezeigt.",
            flush=True,
        )

    except Exception as exc:
        print(
            f"Shutdown-Bild konnte nicht angezeigt werden: {exc}",
            flush=True,
        )

    time.sleep(1)

    print(
        "Raspberry Pi wird heruntergefahren.",
        flush=True,
    )

    subprocess.run(
        ["/usr/sbin/shutdown", "-h", "now"],
        check=False,
    )


def pressed(name):
    press_started[name] = time.monotonic()


def released(name):
    started = press_started.pop(name, None)

    if started is None:
        return

    duration = time.monotonic() - started

    if duration >= LONG_PRESS_SECONDS:
        print(
            f"Taste {name} lang gedrueckt ({duration:.1f}s)",
            flush=True,
        )

        shutdown()
        return

    if name == "A":
        previous_plugin()

    elif name == "B":
        next_plugin()

    else:
        print(
            f"Taste {name} kurz gedrueckt - keine Funktion",
            flush=True,
        )


buttons = []

for name, pin in BUTTONS.items():
    button = Button(
        pin,
        pull_up=True,
        bounce_time=0.05,
    )

    button.when_pressed = (
        lambda n=name: pressed(n)
    )

    button.when_released = (
        lambda n=name: released(n)
    )

    buttons.append(button)


print(
    "Button-Steuerung aktiv: "
    "A=zurueck, B=weiter, C/D=ohne Funktion, "
    "jede Taste 3s=Shutdown",
    flush=True,
)

while True:
    time.sleep(1)
