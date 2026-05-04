import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import '../models/note.dart';
import 'node_service.dart';
import 'note_service.dart';

class ServiceLocator {
  static final ServiceLocator instance = ServiceLocator._();

  late final NodeService nodeService;
  late final NoteService noteService;

  void init({required Box<Node> templatesBox, required Box<Note> notesBox}) {
    noteService = NoteService(notesBox);
    nodeService = NodeService(templatesBox, noteService);
  }

  ServiceLocator._();
}
