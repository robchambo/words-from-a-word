# Audio credits

## PRE-LAUNCH TODO — source real audio

The `.mp3` files in this directory are currently **zero-byte placeholders**. They ship with Phase 4 so the full audio plumbing (preloading, mute gate, SFX wiring, settings toggle) can be built and tested without blocking on asset sourcing. At runtime, `AudioCache.load` and `AudioPlayer.play` calls are wrapped in try/catch and fail silently — the app runs normally, just without sound.

**Before launch**, replace each placeholder with a real CC0-licensed clip sourced from [freesound.org](https://freesound.org). For each clip, trim to the target duration in Audacity (or similar), export as 96 kbps mono MP3, and overwrite the placeholder. Record the source URL below.

| Filename | Brief | Max duration | Source URL / author |
|---|---|---|---|
| `tap.mp3` | Short percussive click — paper/pencil tap feel | 80 ms | _TODO_ |
| `success.mp3` | Ascending 2-3 note chime — positive, soft | 400 ms | _TODO_ |
| `error.mp3` | Low thud or muted "nope" — not harsh | 300 ms | _TODO_ |
| `level_complete.mp3` | Celebratory flourish — 3-4 ascending notes + tiny sparkle | 1500 ms | _TODO_ |
| `hint_reveal.mp3` | Soft sparkle, similar to success but gentler | 400 ms | _TODO_ |
| `free_hint_earned.mp3` | Amber/warm chime, rewarding tone | 800 ms | _TODO_ |
| `bonus_refill.mp3` | Short positive chirp | 500 ms | _TODO_ |

Format per row once sourced: `https://freesound.org/s/XXXXX by USER (CC0)`.
