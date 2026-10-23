import 'package:intl/intl.dart';
import '../models/node.dart';

/// Parses a legacy day-plan name (`dd.MM.yyyy`). Returns null if the name is
/// not a date.
DateTime? parseLegacyPlanName(String name) {
  try {
    return DateFormat('dd.MM.yyyy').parseStrict(name);
  } on FormatException {
    return null;
  }
}

/// Date (without time) of a day plan: `Node.plannedDate`, falling back to the
/// legacy `dd.MM.yyyy` name for data created before #114. The name is a free
/// title and does not define the date anymore.
DateTime? planDateOf(Node node) {
  final d = node.plannedDate;
  if (d != null) return DateTime(d.year, d.month, d.day);
  return parseLegacyPlanName(node.name);
}
