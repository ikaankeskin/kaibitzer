# Kaibitzer

A Flutter Go app for Android, iOS, and web. Play on a customizable goban, switch rule variants, and ask an on-device coach for recommended moves.

## Features

- **Board sizes** from 5×5 to 21×21, including 9, 13, and 19
- **Rule sets:** Japanese, Chinese, AGA, New Zealand
- **Capture Go** (first to N captives) for teaching games
- **Handicap, komi, themes** (Kaya, Night, Ink, Jade), stone styles, coordinates
- **Kaibitzer coach:** recommended moves, weak groups, score estimates, questions like `why Q16`

The coach is a local tutor (heuristics + explanations). It is not KataGo; it is meant for study and conversation at the board.

## Run

```bash
flutter pub get
flutter test
flutter run -d chrome
flutter run
```
