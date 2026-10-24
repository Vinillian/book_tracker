## [1.3.0] - Unreleased
### Added
- Calendar: tapping a day opens its plan directly; for a day without a plan a bottom sheet offers "Empty day" or "From template" (#113)
- Calendar markers now distinguish days that have a plan (ring) from days with completed work in History (filled dot), with a small legend (#113)
- Day screen: read-only "Done" section listing the day's History entries (#113)
- Any task can now have subtasks while keeping its own checkbox or steps: the task card shows a "Подзадачи" ("Subtasks") button for every task; the task's own progress counts together with its subtasks, a task with its own progress opens its card on tap and expands with the chevron (#111, part 1)
- "Move to…" in the editor: move one or several tasks (also via multi-select) into another task or folder of the edited tree, with "Undo" (#111, part 2)
- Swipe-to-delete with "Undo" for tasks in the editor (#110)
- Swipe-to-delete with "Undo" for plans and books; notes and History are removed only after the undo window closes, so closing the app in between loses nothing (#110)

### Fixed
- Editor and item screens no longer return their result via `Navigator.pop` in `dispose()`; the Back button now saves, which fixes lost edits and the "deactivated widget's ancestor" exception (#115)
- Calendar markers refresh after returning from a day screen, and list items no longer show the task name twice (#113)
- "Undo" snackbars close on their own instead of staying on screen (#124)
- Opening a day without a note no longer throws "setState() or markNeedsBuild() called during build" (#123)

- Day plans are now identified by their `plannedDate` instead of by a `dd.MM.yyyy` title: renaming a day no longer breaks its link to the calendar or lets a duplicate day be created. Old data is migrated lazily on startup and old backups still import (#114)

### Changed
- Generated backup files under `backups/` are no longer tracked in git (#118)

## [1.1.1] - 2026-07-XX
### Fixed
- Activities with the same name now correctly sum on the heatmap instead of overwriting each other (#70)
- EditorScreen no longer performs a duplicate Navigator.pop on save (#71)
- Backup restore (importAll) is now atomic — a corrupted backup file no longer wipes existing data (#72)
- Corrupted Hive box files are now preserved (renamed) instead of silently deleted, with a startup notice (#76)

## [1.2.0] - 2026-07-27
### Added
- Per-category backup export now supports date-range filtering (with 2 weeks/month/quarter presets, plus a custom range) for Plans and History (#92)
- Exported category files now use an envelope format (`schemaVersion`, `category`, `exportedRange`, `items`) instead of a bare array, while still reading old bare-array files for backward compatibility (#92)
- Configurable merge strategy on import — "Add new" or "Replace whole list" — selectable before importing Standard Tasks or Tracked Activities (#93)
- Importing Plans now automatically imports and replaces the linked History in the same operation, scoped to the same date range as the Plans file (#94)

### Fixed
- Category import is now atomic — a malformed import file no longer partially writes into the box before failing (#93)
- Category import validates the file's category against the expected one and rejects mismatched files before writing anything (#93)
- Restoring Plans no longer leaves History out of sync with the restored date range — History entries are now removed precisely by which Plan's node tree they belonged to, not by date, avoiding accidental deletion of unrelated History (#94)

### Changed
- Notes export/import is now scoped to inbox notes only; day-linked notes are out of scope for this operation (#92)
- The standalone "Import History" action has been removed — importing History is no longer a separate user choice, it's part of importing Plans (#94)
- Backup and category export files are now gzip-compressed to reduce file size, saved with a `.gz` extension so the system file picker recognizes them correctly; import auto-detects gzip vs. plain-JSON and old uncompressed backups still work (#100)
- Plans and History export now share a single date range instead of two independently selectable ranges, removing the possibility of exporting them with diverging dates (#64)
- Item detail screen (ViewItemScreen) now shows whether a task is tracked on the heatmap, with a quick action to add or re-enable tracking directly from there instead of only via the Tracked Activities screen (#95)
- Backup/Restore screen redesigned around a single category dropdown instead of a button grid, with context-sensitive controls (date range for Plans/History, merge strategy for Standard Tasks/Tracked Activities) shown per selected category (#64)
- Backup and category export files are now gzip-compressed to reduce file size, with automatic detection and fallback so older uncompressed backups still import correctly (#100)