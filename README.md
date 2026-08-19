# InkyPi Inky Impression 7.3 Buttons

Hardware button controls for InkyPi on the Pimoroni Inky Impression 7.3".

## Features

- Button A: previous playlist item
- Button B: next playlist item
- Button C/D: currently unused
- Long press on any button: display a shutdown screen and safely power off the Raspberry Pi
- Runs automatically as a systemd service
- Normal InkyPi playlist automation continues to work

## Hardware

Designed for the Pimoroni Inky Impression 7.3" with the built-in buttons.

GPIO mapping:

- A: GPIO 5
- B: GPIO 6
- C: GPIO 16
- D: GPIO 24

## Requirements

- InkyPi
- Python 3
- gpiozero
- lgpio
- requests
- Pimoroni Inky library

The additional Python dependencies must be installed into the InkyPi virtual environment.

## Button behaviour

A short press on Button A displays the previous item of the currently active playlist.

A short press on Button B displays the next item.

Buttons C and D currently have no short-press function.

Holding any of the four buttons for at least 3 seconds displays a "Shutting down..." screen and then safely shuts down the Raspberry Pi.

## Playlist automation

The button controller does not replace or disable InkyPi's normal playlist system.

InkyPi continues to update and cycle playlists automatically. The buttons provide an optional manual way to switch the displayed item.

## InkyPi integration

The controller uses two additional internal HTTP endpoints:

- /display_plugin_cached
- /shutdown_screen

These allow the button service to request display changes through the running InkyPi process instead of accessing the display hardware simultaneously from two processes.

## E-Ink refresh time

The button itself is detected immediately. The Pimoroni Inky Impression 7.3" still requires its normal physical 7-colour E-Ink refresh time before the new image is fully visible.

## Tested with

InkyPi main branch commit:

73c21a1

Hardware:

Pimoroni Inky Impression 7.3"

## License

MIT
