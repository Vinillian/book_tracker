# Book Planner

**Book Planner** is a Flutter application for organizing books, daily plans, reusable task templates, and personal routines. It combines hierarchical task progress with an independent record of time spent.

![Version](https://img.shields.io/badge/version-1.4.0%2B5-blue)
![License](https://img.shields.io/badge/license-MIT-green)

The current application interface is in Russian.

## Features

### Books and tasks

- Organize books into nested chapters, sections, folders, and tasks.
- Track task completion with either a checkbox or a step counter.
- Tasks may keep their own progress even when they contain subtasks.
- Set an optional start time and organize the day by time of day.
- Move, reorder, copy, and edit tasks; multi-select operations and undo are available in relevant flows.

### Daily planning

- Create an empty day or start from a reusable template.
- Add tasks quickly from the day screen or choose from Standard Tasks without leaving the plan.
- Copy a day to another date and add template tasks to an existing day.
- Reuse and duplicate templates, or load tasks from one template into another.
- Assign templates to books, ordinary days, work days, or days off.
- Configure a repeating work schedule, including the number of work days and days off, an anchor date, and individual day overrides.
- Generate plans for a date range from the work schedule and matching templates. Existing plans are not overwritten; the generator previews the result and supports undo.
- Delete plans for a selected period, with an option to keep days that already contain progress.

### Independent time tracking

Time is a separate measurement available on checkbox and step-based tasks. It is not a third task type and does not require an enable switch.

- Set an optional time goal in minutes for either task type.
- Log multiple time sessions using quick-add buttons or a custom duration.
- Edit or delete individual sessions.
- View logged time and logged / target time separately in task details, task lists, plans, and the calendar.
- Reaching a time goal does not check a task, increase completed steps, or change the plan's primary progress percentage.

### Heatmap and statistics

- Track selected activities in a GitHub-style heatmap.
- Activities are linked by a tracking ID, so related instances can contribute to the same row.
- The heatmap combines checkbox / step progress with time spent. For time, 20 minutes contributes one point; partial points are preserved, and 60 minutes corresponds to full time-based intensity.
- Choose a display period from two weeks up to one year.
- Review overall completion, progress leaders, and the activity calendar in Statistics.

### Notes and data backup

- Keep quick notes in the Inbox.
- Add notes to planning days.
- Export and import individual data categories, including date-scoped plan and history files.
- Create a full backup containing books, plans, templates, notes, history, Standard Tasks, tracked activities, and the work schedule.

### Other

- Light, dark, and system theme modes.
- Local reactive state management with Provider.
- Local persistence using Hive.

## Requirements

- Flutter SDK with a bundled Dart SDK satisfying the constraint in `pubspec.yaml`: `^3.11.0` (Dart 3.11.0 or newer, below 4.0.0).
- Android Studio or Visual Studio Code with the Flutter and Dart extensions.
- The Android SDK and an Android emulator or device to run or build the Android app.

The repository contains Flutter platform folders for Android, iOS, Linux, macOS, Web, and Windows. Each target requires its corresponding platform toolchain; the Android commands below are the documented build example.

## Getting started

Clone the repository and install the dependencies:

```bash
git clone https://github.com/Vinillian/book_tracker.git
cd book_tracker
flutter pub get
```

Run the app on a connected device or emulator:

```bash
flutter devices
flutter run
```

## Development checks

Run the analyzer:

```bash
flutter analyze
```

Run the complete test suite:

```bash
flutter test
```

## Build an Android APK

Create a release APK:

```bash
flutter build apk --release
```

The APK is created at:

`build/app/outputs/flutter-apk/app-release.apk`

You can also check the [GitHub Releases](https://github.com/Vinillian/book_tracker/releases) page for published builds, when available.

## Storage, backup, and sync status

Application data is stored locally on the device in Hive. Backup and restore are user-initiated through the app's Import / Export screen. A full backup includes the work schedule as well as the main app data.

**Cloud features are not implemented yet.** The current app does not provide account sign-in, automatic cloud backup, or real-time synchronization between devices. Keep exported backup files somewhere safe; the local database and exported files are not automatically synchronized to another device.

## Project structure

- `lib/models/` — data models.
- `lib/providers/` — application state and Provider integration.
- `lib/screens/` — application screens.
- `lib/services/` — storage and domain services, including Hive startup and heatmap calculation.
- `lib/utils/` — reusable application logic and file-transfer helpers.
- `lib/widgets/` — reusable widgets.
- `test/` — unit and widget tests.

See [CHANGELOG.md](CHANGELOG.md) for the detailed change history.

## License

This project is distributed under the MIT License. See [LICENSE](LICENSE) for details.

For questions, bug reports, or feature suggestions, [open an issue](https://github.com/Vinillian/book_tracker/issues).
