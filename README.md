# Kaibitzer

A Flutter Go app for Android, iOS, and web. Play on a customizable goban, switch rule variants, play against a computer opponent, and ask an on-device coach for recommended moves.

## Features

- **Vs computer** (easy / medium / hard) or pass-and-play
- **Board sizes** from 5×5 to 21×21, including 9, 13, and 19
- **Rule sets:** Japanese, Chinese, AGA, New Zealand
- **Capture Go** (first to N captives) for teaching games
- **Handicap, komi, themes** (Kaya, Night, Ink, Jade), stone styles, coordinates
- **Kaibitzer coach:** recommended moves, weak groups, score estimates, questions like `why Q16`

The computer and coach use the same local heuristics. They are not KataGo.

## Run

```bash
flutter pub get
flutter test
flutter run -d chrome
flutter run
```
