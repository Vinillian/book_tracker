```markdown
# Book Planner

**A Flutter app for tracking learning progress through books and daily plans.**

![Version](https://img.shields.io/badge/version-1.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 📚 **Books** – hierarchical structure of chapters and tasks, with single checkboxes or step‑by‑step progress.
- 📅 **Planner days** – create daily plans from templates or empty, each with its own note.
- 🔥 **Activity Heatmap** – visualise your daily progress; tasks with the same name are tracked together.
- 📋 **Standard Tasks** – reusable task templates that integrate with the heatmap and plans.
- 📈 **Statistics** – overall progress, top items, and an activity calendar.
- 📝 **Inbox** – quick notes without categories.
- 💾 **Backup & Restore** – export/import all data (books, plans, notes, history, tracked activities) as JSON.
- 🌗 **Light / Dark / System theme**.
- ✨ **Bulk edit & quick‑add** – multi‑select tasks in the editor, continuous leaf creation with "Add another?" dialog.
- 🗓️ **Auto‑scrolling calendar** – activity calendar jumps straight to today.
- 📋 **Collapsible day notes** – long notes show a preview and expand with internal scroll.
- ⚡ **Reactive UI** – Provider‑based state management.

## What's New in v1.1.0

- **Activity Heatmap** – a new screen that shows your daily task completions as a colour‑coded grid.
  - Tasks with identical names (case‑insensitive) share the same tracking entry.
  - Period selector: 2 weeks, 1 month, 3 months, 6 months, 1 year.
  - Sticky task names column, compact cells, and a burger menu with theme support.
- **Standard Tasks integration** – standard tasks now inherit the `trackingId` of existing leaf tasks, so adding a standard task to a plan contributes to the same heatmap entry.
- **Fixed deletion/editing of imported standard tasks** – tasks restored from backup are now fully manageable.
- **Search bar** in the “Pick Task for Tracking” screen for easier discovery.
- **Backup extended** – tracked activities are now included in full backups.

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