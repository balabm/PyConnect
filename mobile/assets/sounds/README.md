# Sound Assets

This directory contains audio files used for KDS new-order chimes and QR scanner
success/error feedback. The Flutter code references these files via
`AssetSource('sounds/success.mp3')` and `AssetSource('sounds/error.mp3')`.

## Required Files

- `success.mp3` — short positive chime played on KDS new order and QR scan success
- `error.mp3` — short error buzzer played on QR scan duplicate/invalid

## Adding the Files

Drop royalty-free MP3 files here. The code uses try/catch around AudioPlayer.play()
so missing files fail silently (no crash), but audio feedback will not work until
the files are present.

Recommended sources:
- https://mixkit.co/free-sound-effects/
- https://pixabay.com/sound-effects/

Keep files under 100KB for fast loading.
