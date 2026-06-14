// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'standard_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StandardTaskAdapter extends TypeAdapter<StandardTask> {
  @override
  final int typeId = 4;

  @override
  StandardTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StandardTask(
      id: fields[0] as String?,
      name: fields[1] as String,
      stepType: fields[2] as String,
      totalSteps: fields[3] as int,
      excludeFromHistory: fields[4] as bool,
      colorValue: fields[5] as int?,
      trackingId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StandardTask obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.stepType)
      ..writeByte(3)
      ..write(obj.totalSteps)
      ..writeByte(4)
      ..write(obj.excludeFromHistory)
      ..writeByte(5)
      ..write(obj.colorValue)
      ..writeByte(6)
      ..write(obj.trackingId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StandardTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
