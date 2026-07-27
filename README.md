# Echo — An AAC (Augmentative & Alternative Communication) Assistant

Echo turns an ordinary smartphone or tablet into a voice-emitting communication
board for **non-verbal and speech-impaired individuals of all ages** — people
with autism, cerebral palsy, or those recovering from a stroke or accident — and
for the caregivers who support them.

Tap a tile and Echo speaks the phrase aloud. It is **offline-first**,
**age-neutral** by design (clean, modern, high-contrast — never childish), and
fully customizable by caregivers.

Aligned with **UN SDG 3 (Good Health & Well-Being)** and **SDG 10 (Reduced
Inequalities)**.

> Author: Aldrin P. Sianson · Course project (Week 2 — Application Development Kickoff)

## Features

- **Speak board** — a responsive grid of high-contrast communication tiles;
  tapping one speaks its phrase (Text-to-Speech).
- **Emergency SOS** — a raised centre button opening a crisis screen with a
  **press-and-hold (2s) safety mechanism** so an alert is never fired by accident.
- **Caregiver board editor (full CRUD)** — add, rename, recolour, re-icon, and
  delete tiles from Settings → *Edit communication board*.
- **Stats** — live daily communication count, most-used tile, and recent activity
  (Settings → *Stats*).
- **Light & dark themes** — light by default, toggle in Settings. A calm, cool
  blue palette in both.
- **Accessibility** — large tap targets, screen-reader labels, focus outlines,
  and reduced-motion support.

## Project structure

```
lib/
├── main.dart            # app entry, theme wiring, shell + navigation
├── models/              # CommTile, Utterance (plain data)
├── state/               # TileState (ChangeNotifier) — tiles, tab, theme, TTS
├── theme/               # colour palette (light/dark), tile accents & icons
├── views/               # landing, speak, emergency, settings, stats, board editor
└── widgets/             # header, bottom nav, tile, editor sheet, shared pieces
test/                    # widget & unit tests
```

State is managed with the `provider` package. Text-to-Speech is currently
stubbed in `TileState.speak()` — the single seam where `flutter_tts` will be
wired in.

## Running the app

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
flutter pub get
flutter run -d chrome      # run in the browser (no extra setup)
# or: flutter run           # pick a connected phone / emulator / desktop
```

## Tests

```bash
flutter analyze
flutter test
```

## Roadmap

- Wire native Text-to-Speech (`flutter_tts`).
- Persist tiles, theme, and settings (SQLite / Hive / shared_preferences).
- High-volume emergency siren audio.
- Drag-to-reorder tiles and tile categories/folders.
