# Funngro take-home

- **Written answers (Parts 1.1, 1.3, 3, assumptions and questions):** `ANSWERS.md`
- **Part 1 rewrite:** `lib/earnings/earnings_screen.dart`
- **Part 2 pagination screen:** `lib/projects/projects_screen.dart`

## Run
```
flutter create .        # only if android/ and ios/ folders are missing
flutter pub get
flutter run             # use --profile to judge scrolling performance
```
The home screen has one entry for each part. The projects API fails about 1 in 5 calls, so the error and retry states show up quickly.
