import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  // Имена файлов (можно переопределить аргументами командной строки)
  String fullBackupPath = 'full_backup_1782508945110_migrated.json';
  String plansPath = 'plans_cleaned.json';
  String outputPath = 'full_backup_merged.json';

  // Поддержка аргументов: dart merge_plans.dart [fullBackup] [plans] [output]
  if (args.length >= 3) {
    fullBackupPath = args[0];
    plansPath = args[1];
    outputPath = args[2];
  } else if (args.length == 2) {
    fullBackupPath = args[0];
    plansPath = args[1];
  }

  try {
    // 1. Читаем полный бэкап
    final fullFile = File(fullBackupPath);
    if (!await fullFile.exists()) {
      stderr.writeln('❌ Файл $fullBackupPath не найден');
      exit(1);
    }
    final fullContent = await fullFile.readAsString();
    final fullData = jsonDecode(fullContent) as Map<String, dynamic>;

    // 2. Читаем очищенные планы
    final plansFile = File(plansPath);
    if (!await plansFile.exists()) {
      stderr.writeln('❌ Файл $plansPath не найден');
      exit(1);
    }
    final plansContent = await plansFile.readAsString();
    final plansData = jsonDecode(plansContent) as List<dynamic>;

    // 3. Извлекаем существующие шаблоны (все, у кого category != "planner")
    final oldTemplates = fullData['templates'] as List<dynamic>? ?? [];
    final templates = oldTemplates.where((item) {
      final category = item['category'] as String?;
      return category != 'planner';   // оставляем только шаблоны (template или null)
    }).toList();

    // 4. Формируем новый массив: шаблоны + новые планы
    final mergedTemplates = [...templates, ...plansData];

    // 5. Заменяем поле templates
    fullData['templates'] = mergedTemplates;

    // 6. Сохраняем результат
    final outputFile = File(outputPath);
    final encoder = JsonEncoder.withIndent('  ');
    final outputContent = encoder.convert(fullData);
    await outputFile.writeAsString(outputContent);

    print('✅ Готово! Файл сохранён как $outputPath');
    print('📦 Шаблонов: ${templates.length}, планов: ${plansData.length}');
    print('📊 Итоговый размер templates: ${mergedTemplates.length}');
  } catch (e) {
    stderr.writeln('❌ Ошибка: $e');
    exit(1);
  }
}