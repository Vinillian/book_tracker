// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracked_activity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackedActivityAdapter extends TypeAdapter<TrackedActivity> {
  @override
  final int typeId = 5;

  @override
  TrackedActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrackedActivity(
      id: fields[0] as String?,
      nodeId: fields[1] as String,
      name: fields[2] as String,
      colorValue: fields[3] as int,
      stepType: fields[4] as String,
      isActive: fields[5] as bool,
      isRoutine: fields[6] as bool,
      order: fields[7] == null ? 0 : fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TrackedActivity obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nodeId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.stepType)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.isRoutine)
      ..writeByte(7)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackedActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
