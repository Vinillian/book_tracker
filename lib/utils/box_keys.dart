import 'package:hive_flutter/hive_flutter.dart';

/// The key under which the record with [id] is stored in [box], or null if
/// there is none. Records are matched by their id, not by being the same
/// object: a copy of a stored record (a working copy in an editor, a record
/// read back from a file) has the same id and finds the same key (#73, #77).
///
/// The key can be any value, even `0`, so compare the result with `null`, never
/// use it as a condition.
dynamic findKeyById<T>(Box<T> box, String Function(T item) idOf, String id) {
  for (final key in box.keys) {
    final item = box.get(key);
    if (item != null && idOf(item) == id) return key;
  }
  return null;
}
