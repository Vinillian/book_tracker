# Book Planner

**A Flutter app for tracking learning progress through books and daily plans.**

## Features

- 📚 **Books** – hierarchical structure of chapters and tasks, with single checkboxes or step-by-step progress.
- 📅 **Planner days** – create daily plans from templates or empty, each with its own note.
- 📈 **Statistics** – overall progress, top items, and an activity calendar.
- 📝 **Inbox** – quick notes without categories.
- 💾 **Backup & Restore** – export/import all data (books, plans, notes, history) as JSON.
- 🌗 **Light / Dark / System theme**.
- ⚡ **Reactive UI** – Provider-based state management, no manual setState.

## Getting Started

### Prerequisites
- Flutter SDK (>=3.11.0)
- Android Studio or VS Code with Flutter plugin

### Installation
```bash
git clone https://github.com/Vinillian/book_tracker.git
cd book_tracker
flutter pub get
flutter run