# MindMaster

Offline brain-training app. No ads, no trackers, no accounts.

## Status

Two games are playable. The other four are listed in the app as "Coming next"
and are deliberately non-tappable. Nothing here is claimed as built until it is.

| Game | State |
|---|---|
| Math Sprint | Playable, tested |
| Memory Matrix | Playable, tested |
| Pattern Recall | Not built |
| Logic Puzzles | Not built |
| Color Match | Not built |
| Focus Grid | Not built |

## Download

**Android APK (v1.0.1):**
https://github.com/fsix7115-arch/MindMaster/releases/latest/download/MindMaster-v1.0.1.apk

Download it, allow "install unknown apps" for your file manager, open it. No
store account needed. Built with Flutter's debug signing key, so Android shows
an install warning; that is expected and does not affect the app.

## What Memory Matrix does

- Pair matching on 4x4 / 6x6 / 8x8 boards, switchable mid-session
- Fewer moves scores higher; a fast clear adds a time bonus
- The board is dealt by shuffling symbols rather than positions, so a solvable
  layout is guaranteed by construction
- A miss locks the board briefly so both symbols can be read before they flip

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
- **Scoring can never emit Infinity or NaN.** `MemoryMatrixGame.score` crashed
  on a zero-move round; the divisor is clamped and the result is guarded,
  because a scoring crash mid-round is worse than a slightly wrong number.

## Run it

```bash
flutter pub get
flutter run           # connected device or emulator
flutter test          # 40 tests
flutter analyze       # clean
flutter build apk --release
```

## Privacy

No network calls. No analytics. No account. The game is fully playable in
airplane mode.
