# Funngro take-home

- **Written answers (Parts 1.1, 1.3, 3, assumptions and questions):** `ANSWERS.md`
- **State management:** Bloc (`flutter_bloc`)
- **Part 1 rewrite:** `lib/earnings/bloc/` + `lib/earnings/earnings_screen.dart`
- **Part 2 pagination screen:** `lib/projects/bloc/` + `lib/projects/projects_screen.dart`
- **Tests:** `flutter test`

```
lib/
  main.dart
  earnings/
    bloc/            earnings_bloc.dart, earnings_event.dart, earnings_state.dart
    earnings_screen.dart
    earnings_fakes.dart   (stand-ins for the app's real api/models/widgets)
  projects/
    bloc/            projects_bloc.dart, projects_event.dart, projects_state.dart
    projects_api.dart     (provided fake API, unchanged)
    projects_screen.dart
test/
  projects_bloc_test.dart
  widget_test.dart
```

## Run
```
flutter create .        # only if android/ and ios/ folders are missing
flutter pub get
flutter test
flutter run             # use --profile to judge scrolling performance
```
The home screen has one entry for each part. The projects API fails about 1 in 5 calls, so the error and retry states show up quickly.
