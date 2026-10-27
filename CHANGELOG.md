## [1.4.0] - Unreleased
### Added
- Work schedule: Settings → "График работы" (work schedule) sets a repeating schedule (N work days, M days off, an anchor day and its type; first case 2 / 2 with 23.10.2026 as a day off). The day screen shows a "Рабочий день" / "Выходной" (Work day / Day off) label. The type is computed from the rule, nothing is stored per day; no schedule is set by default. `AppSettings` gets the optional field `workSchedule` (HiveField 1). Per-day override and backup of the schedule follow in the next part (#144, part 1)
- Templates for work days and days off: besides "Для дня" and "Для книги" a template can be made "Для рабочего дня" or "Для выходного" (Templates → the tag button of a template, or when creating one; the list has filters "Рабочие" and "Выходные"). Where a day template is offered, the work-day and day-off templates are offered too; old templates work as before. The generator of plans for a period follows (#145, part 1)
- Plan generator: the calendar has a new button "Сгенерировать планы" (generate plans). Pick a period (up to 366 days); the screen previews how many work days and days off will be created from the work schedule and the "Для рабочего дня" / "Для выходного" templates. Days that already have a plan are skipped and listed, days whose type has no template are skipped with a hint to create one, nothing is overwritten. After creating, "Отменить" (Undo) removes the whole batch. Rotating the day-off templates follows (#146)

### Changed
- Calendar: tapping a day now only selects it and shows a short summary under the calendar (the day type, "Выполнено X из Y" (done X of Y), the plan's tasks with start time and progress, and the day's completed entries). The day opens with the "Открыть день" (Open day) button, or "Создать план…" (Create plan…) when the day has no plan (#162)
- Custom launcher icon (an open book with a mini heatmap and a task list) instead of the default Flutter one, with an adaptive version for Android 8+, and the launcher name is now "Book Planner" (#154)
- Templates screen: the row of filter chips (Все / Дни / Рабочие / Выходные / Книги) is replaced by one drop-down list at the top (#158)

### Fixed
- Deleting a task from a book, a day or a template (in the editor, also several at once) now removes its History entries with it, so no completions of deleted tasks stay behind in the calendar and the heatmap. Tracked activities are left as they are on purpose: they are curated by hand (#84)

## [1.3.0] - 2026-10-25
### Added
- Calendar: tapping a day opens its plan directly; for a day without a plan a bottom sheet offers "Empty day" or "From template" (#113)
- Calendar markers now distinguish days that have a plan (ring) from days with completed work in History (filled dot), with a small legend (#113)
- Day screen: read-only "Done" section listing the day's History entries (#113)
- Any task can now have subtasks while keeping its own checkbox or steps: the task card shows a "Подзадачи" ("Subtasks") button for every task; the task's own progress counts together with its subtasks, a task with its own progress opens its card on tap and expands with the chevron (#111, part 1)
- "Move to…" in the editor: move one or several tasks (also via multi-select) into another task or folder of the edited tree, with "Undo" (#111, part 2)
- Optional start time per task (time picker in the task card, clearable): shown in front of the task name; the day screen groups tasks into "Утро" / "День" / "Вечер" (morning / day / evening) and "Без времени" (no time) and sorts them by time once any task has a time. Nothing is stored as folders, existing days and old backups are unchanged (#116)
- Day screen: quick add at the bottom: type a name and press Enter to add a checkbox task, or open the standard-task list with "+" (search, tap to add, the sheet stays open to add several) without leaving the day screen (#109, part 1)
- Day screen: long-press a task and drag it to change the order (a task moves together with its visible subtasks). With tasks grouped by time only the "Без времени" (no time) group can be dragged, the other groups stay sorted by time (#109, part 2)
- Templates carry a target, "Для дня" (day) or "Для книги" (book): chosen when a template is created, changeable with the label button, shown in the list; creating a day or a book offers only the matching templates (and old templates without a target, which stay universal). The template manager has a Все / Дни / Книги filter. `Node` gets the optional field `templateTarget` (HiveField 13); old data and backups load unchanged (#117)
- Template manager: a button on templates that still have "Утро" / "День" / "Вечер" (morning / day / evening) folders moves their tasks to the top level and gives tasks without a time 08:00 / 13:00 / 19:00, so the day screen groups them by time instead; asks first, "Отменить" (Undo) restores the template. New templates are flat already, nothing changes for existing ones unless you press it (#117)
- Day screen menu: "Добавить из шаблона…" (add a template's tasks to this day) and "Копировать день…" (copy the day to another date, completion reset; if a day exists there, the tasks are added to it). Creating a day from a template for a date that already has a day now offers to add the tasks instead of refusing (#117)
- Data model for the new "duration" task type: `Node` gets `targetMinutes` (optional goal) and `loggedMinutes` (HiveField 14 and 15); a duration task counts as one unit in the statistics, done when the goal is reached (or when any time is logged if it has no goal). Copies made from templates or days reset the logged time. No UI yet, old data and backups load unchanged (#112, part 1)
- History for "duration" tasks: `HistoryEntry` gets the optional field `minutes` (HiveField 9) and `HistoryService.recordDurationLog` adds one entry per log without replacing earlier ones, so a task can have several logs per day; a single log can be removed. The heatmap counts the minutes, and the Done section and the calendar show "N мин" ("N min"). No UI to log time yet, old data and backups load unchanged (#112, part 2)
- "Длительность" (duration) task type can now be created: the task card has a segmented "Чекбокс / Шаги / Длительность" (checkbox / steps / duration) choice instead of radio buttons, with an optional goal in minutes. The day screen, the editor, the task view and the tracking lists show the logged time ("25 мин / 1 ч"); a task with a goal turns green when it is reached. Logging time is not possible yet (#112, part 3a)
- Logging time on a duration task: the task view has quick buttons (+5 мин, +15 мин, +30 мин, +1 ч) and "Своё…" (custom, 1-1440 minutes); every log is a separate History entry, so a task can get several a day. Logs are listed under the task and each can be deleted, which also takes its minutes off the task. The heatmap colour of a duration task is scaled by minutes (fully saturated at an hour a day). Not included: duration among standard tasks (#112, part 3b)
- Swipe-to-delete with "Undo" for tasks in the editor (#110)
- Swipe-to-delete with "Undo" for plans and books; notes and History are removed only after the undo window closes, so closing the app in between loses nothing (#110)
- Swipe-to-delete and the trash icon for templates now also offer "Undo" (and swiping is off while a template is being picked) (#125)

### Fixed
- A book created from a template no longer gets `category == 'book'` on every nested task (only the root); the template copy logic is now shared with days (`copyAndReset`) (#117, #78)
- Editor and item screens no longer return their result via `Navigator.pop` in `dispose()`; the Back button now saves, which fixes lost edits and the "deactivated widget's ancestor" exception (#115)
- Calendar markers refresh after returning from a day screen, and list items no longer show the task name twice (#113)
- "Undo" snackbars close on their own instead of staying on screen (#124)
- Opening a day without a note no longer throws "setState() or markNeedsBuild() called during build" (#123)
- Books made from a template before the fix above are repaired on the next start: nested tasks with `category == 'book'` get their own progress and the start-time button back. The repair is idempotent and also runs for books restored from an old backup (#139)
- A standard task added with "+" now joins the existing line of the same habit: its `trackingId` is taken from an already tracked activity (or an existing task) with the same name, so it is tracked right away and no duplicate row appears in the heatmap; the task card uses the same rule. Rows that were already duplicated are not merged (#149)

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