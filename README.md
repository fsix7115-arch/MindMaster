# MindMaster

Offline brain-training app. No ads, no trackers, no accounts.

## Status

**v1.0.0 — Math Sprint only.** Five more games are listed in the app as
"Coming next" and are deliberately non-tappable. Nothing in this repo is
claimed as built until it is.

| Game | State |
|---|---|
| Math Sprint | Playable, tested |
| Memory Matrix | Not built |
| Pattern Recall | Not built |
| Logic Puzzles | Not built |
| Color Match | Not built |
| Focus Grid | Not built |

## What Math Sprint does

- 60 second round, four answer keys on screen
- `+ − × ÷`, difficulty scales with score across three tiers
- Streak multiplier 1x → 5x; a wrong answer resets it
- Division is always exact, subtraction never negative
- Correct answers light green, wrong answers leave the right key visible so you
  can learn the mistake rather than just see red

## Design decisions worth knowing

- **Game rules live in pure Dart** (`math_sprint_game.dart`), separate from the
  widgets. That is why they can be unit-tested without a display, and why 21 tests
  cover generation and scoring.
- **The countdown clamps dt to 0.25s.** If the app is backgrounded mid-round the
  clock pauses instead of instantly ending the round.
- **Feedback uses shape as well as colour** (`✓`/`✗`), so correct/wrong is
  readable without colour vision.
- **Unbuilt games are visible but inert.** Hiding them would imply features that
  do not exist.

## Run it

```bash
flutter pub get
flutter run           # connected device or emulator
flutter test          # 21 tests
flutter analyze       # clean
flutter build apk --release
```

## Privacy

No network calls. No analytics. No account. The game is fully playable in
airplane mode.
