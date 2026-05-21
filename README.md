Вот финальный `README.md` для версии `1.0.3`. Просто скопируйте его в файл.

```markdown
# Book Planner

**A Flutter app for tracking learning progress through books and daily plans.**

![Version](https://img.shields.io/badge/version-1.0.3-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 📚 **Books** – hierarchical structure of chapters and tasks, with single checkboxes or step‑by‑step progress.
- 📅 **Planner days** – create daily plans from templates or empty, each with its own note.
- 📈 **Statistics** – overall progress, top items, and an activity calendar.
- 📝 **Inbox** – quick notes without categories.
- 💾 **Backup & Restore** – export/import all data (books, plans, notes, history) as JSON.
- 🌗 **Light / Dark / System theme**.
- ✨ **Bulk edit & quick‑add** – multi‑select tasks in the editor, continuous leaf creation with "Add another?" dialog.
- 🗓️ **Auto‑scrolling calendar** – activity calendar jumps straight to today.
- 📋 **Collapsible day notes** – long notes show a preview and expand with internal scroll.
- ⚡ **Reactive UI** – Provider‑based state management.

## What's New in v1.0.3

- **Inbox deletion fixed** – notes are now deleted instantly, both old and new.
- **Planner task count** – shows the number of non‑routine leaf tasks (excluding folders and routine items). Example: "Weekend day" template shows 10 tasks instead of 3.
- **Quick‑add leaf UX** – after saving a leaf, a dialog asks "Add another?" – you decide whether to continue or stop.

## Getting Started

### Prerequisites
- Flutter SDK (>=3.11.0)
- Android Studio or VS Code with Flutter plugin

### Installation

#### From source
```bash
git clone https://github.com/Vinillian/book_tracker.git
cd book_tracker
flutter pub get
flutter run
```

#### Download APK
Grab the latest APK from the [Releases](https://github.com/Vinillian/book_tracker/releases) page.

## Building APK

```bash
flutter build apk --release
```

The APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

## License

MIT License – see [LICENSE](LICENSE) file for details.

---

For questions or suggestions, open an [issue](https://github.com/Vinillian/book_tracker/issues).
```
