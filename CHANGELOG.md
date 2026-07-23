## [1.1.1] - 2026-07-XX
### Fixed
- Activities with the same name now correctly sum on the heatmap instead of overwriting each other (#70)
- EditorScreen no longer performs a duplicate Navigator.pop on save (#71)
- Backup restore (importAll) is now atomic — a corrupted backup file no longer wipes existing data (#72)
- Corrupted Hive box files are now preserved (renamed) instead of silently deleted, with a startup notice (#76)