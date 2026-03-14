// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistoryEntryAdapter extends TypeAdapter<HistoryEntry> {
  @override
  final int typeId = 2;

  @override
  HistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistoryEntry(
      id: fields[0] as String?,
      bookId: fields[1] as String,
      nodeId: fields[2] as String,
      date: fields[3] as DateTime,
      nodeName: fields[4] as String,
      stepType: fields[5] as String,
      completed: fields[6] as bool?,
      completedSteps: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HistoryEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.nodeId)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.nodeName)
      ..writeByte(5)
      ..write(obj.stepType)
      ..writeByte(6)
      ..write(obj.completed)
      ..writeByte(7)
      ..write(obj.completedSteps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
