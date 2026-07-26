## [1.1.1] - 2026-07-XX
### Fixed
- Activities with the same name now correctly sum on the heatmap instead of overwriting each other (#70)
- EditorScreen no longer performs a duplicate Navigator.pop on save (#71)
- Backup restore (importAll) is now atomic — a corrupted backup file no longer wipes existing data (#72)
- Corrupted Hive box files are now preserved (renamed) instead of silently deleted, with a startup notice (#76)

## [Unreleased]
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