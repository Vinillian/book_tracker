import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

// ---------- Модели данных (упрощённые) ----------
class Node {
  String name;
  List<Node> children;
  bool isExpanded;
  DateTime? plannedDate;
  bool completed;
  String stepType;
  int totalSteps;
  int completedSteps;
  String id;
  String? category;
  bool excludeFromHistory;
  String trackingId;

  Node({
    required this.name,
    required this.children,
    this.isExpanded = false,
    this.plannedDate,
    this.completed = false,
    this.stepType = 'single',
    this.totalSteps = 1,
    this.completedSteps = 0,
    String? id,
    this.category,
    this.excludeFromHistory = false,
    String? trackingId,
  }) : id = id ?? const Uuid().v4(),
        trackingId = trackingId ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'name': name,
    'children': children.map((c) => c.toJson()).toList(),
    'plannedDate': plannedDate?.toIso8601String(),
    'completed': completed,
    'stepType': stepType,
    'totalSteps': totalSteps,
    'completedSteps': completedSteps,
    'id': id,
    'category': category,
    'excludeFromHistory': excludeFromHistory,
    'trackingId': trackingId,
  };

  factory Node.fromJson(Map<String, dynamic> json) => Node(
    name: json['name'],
    children: (json['children'] as List)
        .map((c) => Node.fromJson(c))
        .toList(),
    plannedDate: json['plannedDate'] != null
        ? DateTime.parse(json['plannedDate'])
        : null,
    completed: json['completed'] ?? false,
    stepType: json['stepType'] ?? 'single',
    totalSteps: json['totalSteps'] ?? 1,
    completedSteps: json['completedSteps'] ?? 0,
    id: json['id'],
    category: json['category'],
    excludeFromHistory: json['excludeFromHistory'] ?? false,
    trackingId: json['trackingId'] ?? const Uuid().v4(),
  );
}

class StandardTask {
  String id;
  String name;
  String stepType;
  int totalSteps;
  bool excludeFromHistory;
  int? colorValue;
  String trackingId;

  StandardTask({
    String? id,
    required this.name,
    required this.stepType,
    this.totalSteps = 1,
    this.excludeFromHistory = false,
    this.colorValue,
    String? trackingId,
  }) : id = id ?? const Uuid().v4(),
        trackingId = trackingId ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'stepType': stepType,
    'totalSteps': totalSteps,
    'excludeFromHistory': excludeFromHistory,
    'colorValue': colorValue,
    'trackingId': trackingId,
  };

  factory StandardTask.fromJson(Map<String, dynamic> json) => StandardTask(
    id: json['id'],
    name: json['name'],
    stepType: json['stepType'],
    totalSteps: json['totalSteps'] ?? 1,
    excludeFromHistory: json['excludeFromHistory'] ?? false,
    colorValue: json['colorValue'],
    trackingId: json['trackingId'] ?? const Uuid().v4(),
  );
}

class HistoryEntry {
  String id;
  String bookId;
  String nodeId;
  DateTime date;
  String nodeName;
  String stepType;
  bool? completed;
  int? completedSteps;
  String trackingId;

  HistoryEntry({
    String? id,
    required this.bookId,
    required this.nodeId,
    required this.date,
    required this.nodeName,
    required this.stepType,
    this.completed,
    this.completedSteps,
    required this.trackingId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'nodeId': nodeId,
    'date': date.toIso8601String(),
    'nodeName': nodeName,
    'stepType': stepType,
    'completed': completed,
    'completedSteps': completedSteps,
    'trackingId': trackingId,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'],
    bookId: json['bookId'],
    nodeId: json['nodeId'],
    date: DateTime.parse(json['date']),
    nodeName: json['nodeName'],
    stepType: json['stepType'],
    completed: json['completed'],
    completedSteps: json['completedSteps'],
    trackingId: json['trackingId'] ?? '',
  );
}

// ---------- Правило миграции ----------
class MigrationRule {
  final List<String> oldNames;
  final String newName;
  final String stepType;
  final int totalSteps;
  final String? trackingId;
  final bool excludeFromHistory;

  MigrationRule({
    required this.oldNames,
    required this.newName,
    required this.stepType,
    required this.totalSteps,
    this.trackingId,
    this.excludeFromHistory = false,
  });
}

// ---------- Основной скрипт ----------
void main(List<String> args) async {
  // -----------------------------------------------------------------
  // 1. ПРАВИЛА
  // -----------------------------------------------------------------
  final rules = [
    // Духовные практики
    MigrationRule(
      oldNames: ['Махамантра 4 круга'],
      newName: 'Махамантра 4 круга',
      stepType: 'stepByStep',
      totalSteps: 4,
      trackingId: '1358352b-d8de-4734-80b1-0631bfc555c3',
    ),
    MigrationRule(
      oldNames: ['Заучивание молитв (2 сессии)'],
      newName: 'Заучивание молитв (2 сессии)',
      stepType: 'stepByStep',
      totalSteps: 2,
      trackingId: 'acd89564-dbbd-446d-b0ce-29d064dee55a',
    ),
    MigrationRule(
      oldNames: ['Чтение философии (1 сессия)'],
      newName: 'Чтение философии (2 сессии)',
      stepType: 'stepByStep',
      totalSteps: 2,
      trackingId: '8920f81d-87d0-4654-8d5c-2e2d46809258',
    ),
    MigrationRule(
      oldNames: ['Изучение внутренней алхимии 2 сессии'],
      newName: 'Изучение внутренней алхимии',
      stepType: 'stepByStep',
      totalSteps: 2,
      trackingId: 'c3a7981c-4ce6-4005-882f-deb31416b24e',
    ),
    MigrationRule(
      oldNames: ['Аюрведа 2 сессии изучение'],
      newName: 'Аюрведа',
      stepType: 'stepByStep',
      totalSteps: 2,
      trackingId: '1d6a4c74-fbba-4dc3-8226-60ac53fc3b08',
    ),
    MigrationRule(
      oldNames: ['Вечер без еды'],
      newName: 'Вечер без еды',
      stepType: 'single',
      totalSteps: 1,
      trackingId: '53e1ee22-1e49-4d45-ba20-c9f79052a8bc',
    ),

    // Программирование
    MigrationRule(
      oldNames: ['Codewars (1 задача)', 'Codewars (5 задач)'],
      newName: 'Codewars (4задачи)',
      stepType: 'stepByStep',
      totalSteps: 4,
      trackingId: 'cddc81e5-55ee-4132-906e-0eeb9b8f86a2',
    ),
    MigrationRule(
      oldNames: ['Codechef js 2 сессии'],
      newName: 'Codechef',
      stepType: 'stepByStep',
      totalSteps: 2,
    ),
    MigrationRule(
      oldNames: [
        'Написал простейший калькулятор с html с функцией суммирования',
        'Сделал шпору по приведению типов html',
        'Сделал шпору по приведению типов markdown',
        'Зарегался на Codechef roadmap js',
        'Сделал рефакторинг book_planner',
        'fix book_planner',
      ],
      newName: 'Разработка вайбкодинг',
      stepType: 'single',
      totalSteps: 1,
      trackingId: '7f525015-7c74-4b6f-b9c2-20cde5896d2e',
    ),

    // Математика
    MigrationRule(
      oldNames: [
        'Математика 2 сессии',
        'Математика теория множеств 2 часа',
        'Лекци по группам геометрии 30 минут',
      ],
      newName: 'Математика',
      stepType: 'stepByStep',
      totalSteps: 2,
    ),

    // Библиотека
    MigrationRule(
      oldNames: [
        'Библиотека матлогика 2 сессии по 1,5 часа',
        'Библиотека 1,5 часа 2 сессии Успенский',
        'Посещение читального зала',
        'Сходить в библиотеку',
      ],
      newName: 'Библиотека (1 час)',
      stepType: 'single',
      totalSteps: 1,
      trackingId: 'c53bf70b-1fbe-4e29-abd4-6af407e4f08b',
    ),

    // Еда
    MigrationRule(
      oldNames: [
        'испечь морковный пирог',
        'испечь оладьи из старого кефира',
        'Сделал сейтан',
        'Сделал пилюли пяти элементов',
        'Приготовил поесть',
      ],
      newName: 'Приготовление еды',
      stepType: 'single',
      totalSteps: 1,
      trackingId: 'b1b3fb60-ab44-478d-b3d4-fac1102adc1f',
    ),

    // Уборка
    MigrationRule(
      oldNames: ['убрал бардак в комнате', 'Вынести мусор'],
      newName: 'Уборка',
      stepType: 'single',
      totalSteps: 1,
      trackingId: '63989fc1-f0bf-44c3-9ce7-160497f9c135',
    ),

    // Лес
    MigrationRule(
      oldNames: ['Закопать органику, посидеть в лесу'],
      newName: 'Лес',
      stepType: 'single',
      totalSteps: 1,
      trackingId: '5c61242f-5b3e-4ced-aded-8012aa2331ac',
    ),

    // Садоводство
    MigrationRule(
      oldNames: ['Посадить семена', 'Полить цветы у сестры дома'],
      newName: 'Садоводство',
      stepType: 'single',
      totalSteps: 1,
    ),

    // БАДы (рутина, не в историю)
    MigrationRule(
      oldNames: ['Выпить витграсс'],
      newName: 'Приём БАДов',
      stepType: 'single',
      totalSteps: 1,
      excludeFromHistory: true,
    ),

    // Физика
    MigrationRule(
      oldNames: ['Лекция по физике посмотреть наблюдение гипотеза эксперимент'],
      newName: 'Основы Физики урок',
      stepType: 'single',
      totalSteps: 1,
      trackingId: '2dfff2b0-15a1-437e-8b06-772776953479',
    ),

    // История
    MigrationRule(
      oldNames: [
        'История Китая лекция посмотреть',
        'лекция по истории китая 1 час',
      ],
      newName: 'Лекция по истории',
      stepType: 'single',
      totalSteps: 1,
      trackingId: 'db2e6b86-db1f-4676-b72d-d6b56b08c739',
    ),

    // Цитология
    MigrationRule(
      oldNames: ['Лекция по цитологии 30 минут', 'Лекция по цитологии'],
      newName: 'Цитология Урок',
      stepType: 'single',
      totalSteps: 1,
    ),

    // DnD
    MigrationRule(
      oldNames: ['DnD книга игрока 20 мин', 'Чтение Книга Игрока DnD 20 мин'],
      newName: 'Изучение DnD',
      stepType: 'single',
      totalSteps: 1,
    ),
  ];

  final Map<String, MigrationRule> oldNameToRule = {};
  for (var rule in rules) {
    for (var old in rule.oldNames) {
      oldNameToRule[old] = rule;
    }
  }

  // -----------------------------------------------------------------
  // 2. Обработка аргументов
  // -----------------------------------------------------------------
  String backupPath;
  if (args.isNotEmpty) {
    backupPath = args[0];
  } else {
    final dir = Directory.current;
    final files = await dir
        .list()
        .where((e) =>
    e is File &&
        e.path.contains('full_backup_') &&
        e.path.endsWith('.json'))
        .toList();
    if (files.isEmpty) {
      print('❌ Не найден файл бэкапа. Укажите путь как аргумент.');
      return;
    }
    backupPath = (files.first as File).path;
  }

  print('📂 Читаем бэкап: $backupPath');
  final file = File(backupPath);
  final jsonString = await file.readAsString();
  final Map<String, dynamic> data = jsonDecode(jsonString);

  // -----------------------------------------------------------------
  // 3. Миграция планов
  // -----------------------------------------------------------------
  final Map<String, String> oldTrackingIdToNew = {};
  int renamedCount = 0;

  void processNode(Node node) {
    if (node.children.isEmpty && node.stepType != 'folder') {
      final rule = oldNameToRule[node.name];
      if (rule != null) {
        // Сохраняем старый trackingId
        if (node.trackingId != (rule.trackingId ?? '')) {
          oldTrackingIdToNew[node.trackingId] = rule.trackingId ?? const Uuid().v4();
        }

        // Применяем изменения
        final oldName = node.name;
        node.name = rule.newName;
        node.stepType = rule.stepType;
        node.totalSteps = rule.totalSteps;
        node.trackingId = rule.trackingId ?? const Uuid().v4();
        node.excludeFromHistory = rule.excludeFromHistory;

        // Корректируем прогресс
        if (rule.stepType == 'stepByStep') {
          if (node.stepType == 'single') {
            node.completedSteps = node.completed ? 1 : 0;
            node.completed = false;
          } else {
            if (node.completedSteps > node.totalSteps) {
              node.completedSteps = node.totalSteps;
            }
          }
        } else {
          node.completed = node.completed || node.completedSteps > 0;
          node.completedSteps = 0;
        }

        print('🔄 Переименована: "$oldName" -> "${rule.newName}"');
        renamedCount++;
      }
    } else {
      for (var child in node.children) {
        processNode(child);
      }
    }
  }

  // Обрабатываем все шаблоны (как планы, так и шаблоны, если нужно)
  final List<dynamic> templates = data['templates'] ?? [];
  final List<Map<String, dynamic>> newTemplates = [];

  for (var templateJson in templates) {
    final node = Node.fromJson(templateJson);
    // Обновляем планы и шаблоны (убираем условие на category, чтобы обработать всё)
    // Но если хотим только планы, оставляем условие:
    // if (node.category == 'planner') {
    //   processNode(node);
    // }
    // Для переименования во всех шаблонах (включая шаблоны дней) обрабатываем всё:
    processNode(node);
    newTemplates.add(node.toJson());
  }

  data['templates'] = newTemplates;
  print('✅ Переименовано задач: $renamedCount');

  // -----------------------------------------------------------------
  // 4. Обновление стандартных задач
  // -----------------------------------------------------------------
  List<StandardTask> standardTasks = (data['standardTasks'] as List?)
      ?.map((s) => StandardTask.fromJson(s))
      .toList() ?? [];

  final existingTids = standardTasks.map((t) => t.trackingId).toSet();

  for (var rule in rules) {
    final tid = rule.trackingId ?? const Uuid().v4();
    int existingIndex = standardTasks.indexWhere((t) => t.trackingId == tid);
    if (existingIndex != -1) {
      final existing = standardTasks[existingIndex];
      existing.name = rule.newName;
      existing.stepType = rule.stepType;
      existing.totalSteps = rule.totalSteps;
      existing.excludeFromHistory = rule.excludeFromHistory;
      print('✅ Обновлена стандартная задача: ${existing.name}');
    } else {
      final newTask = StandardTask(
        name: rule.newName,
        stepType: rule.stepType,
        totalSteps: rule.totalSteps,
        excludeFromHistory: rule.excludeFromHistory,
        trackingId: tid,
      );
      standardTasks.add(newTask);
      print('➕ Добавлена стандартная задача: ${newTask.name}');
    }
  }

  // Удаляем дубликаты по имени
  final seenNames = <String>{};
  standardTasks = standardTasks.where((t) {
    if (seenNames.contains(t.name)) {
      return false;
    }
    seenNames.add(t.name);
    return true;
  }).toList();

  data['standardTasks'] = standardTasks.map((s) => s.toJson()).toList();

  // -----------------------------------------------------------------
  // 5. (Опционально) Обновление истории
  // -----------------------------------------------------------------
  final history = data['history'] as List? ?? [];
  if (history.isNotEmpty && oldTrackingIdToNew.isNotEmpty) {
    stdout.write('🔄 Обновить trackingId в истории для переименованных задач? (y/n): ');
    final answer = stdin.readLineSync()?.toLowerCase();
    if (answer == 'y' || answer == 'yes') {
      int updated = 0;
      for (var entryJson in history) {
        final entry = HistoryEntry.fromJson(entryJson);
        if (oldTrackingIdToNew.containsKey(entry.trackingId)) {
          entry.trackingId = oldTrackingIdToNew[entry.trackingId]!;
          updated++;
        }
      }
      data['history'] = history.map((e) => HistoryEntry.fromJson(e).toJson()).toList();
      print('📝 Обновлено $updated записей в истории.');
    } else {
      print('⏭️ История не изменена.');
    }
  } else {
    print('ℹ️ История пуста или замен нет.');
  }

  // -----------------------------------------------------------------
  // 6. Запись результата
  // -----------------------------------------------------------------
  final newPath = backupPath.replaceAll('.json', '_migrated_dart_fixed.json');
  final newFile = File(newPath);
  await newFile.writeAsString(jsonEncode(data));
  print('✅ Миграция завершена. Новый файл: $newPath');
}