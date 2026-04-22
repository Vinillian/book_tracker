import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'note.g.dart';

@HiveType(typeId: 3)
class Note {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  String? linkedNodeId; // ID связанного дня (плана)

  Note({
    String? id,
    this.title = '',
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.linkedNodeId,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'linkedNodeId': linkedNodeId,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      linkedNodeId: json['linkedNodeId'],
    );
  }
}
