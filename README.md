# Book Planner

**A Flutter app for tracking learning progress through books and daily plans.**

![Version](https://img.shields.io/badge/version-1.0.2-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 📚 **Books** – hierarchical structure of chapters and tasks, with single checkboxes or step‑by‑step progress.
- 📅 **Planner days** – create daily plans from templates or empty, each with its own note.
- 📈 **Statistics** – overall progress, top items, and an activity calendar.
- 📝 **Inbox** – quick notes without categories.
- 💾 **Backup & Restore** – export/import all data (books, plans, notes, history) as JSON.
- 🌗 **Light / Dark / System theme**.
- ✨ **Bulk edit & quick‑add** – multi‑select tasks in the editor, continuous leaf creation.
- 🗓️ **Auto‑scrolling calendar** – activity calendar jumps straight to today.
- 📋 **Collapsible day notes** – long notes show a preview and expand with internal scroll.
- ⚡ **Reactive UI** – Provider‑based state management, no manual setState.

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