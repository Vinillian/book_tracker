// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NodeAdapter extends TypeAdapter<Node> {
  @override
  final int typeId = 0;

  @override
  Node read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Node(
      name: fields[0] as String,
      children: (fields[1] as List).cast<Node>(),
      isExpanded: fields[2] as bool,
      plannedDate: fields[3] as DateTime?,
      completed: fields[4] as bool,
      stepType: fields[5] as String,
      totalSteps: fields[6] as int,
      completedSteps: fields[7] as int,
      id: fields[8] as String?,
      category: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Node obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.children)
      ..writeByte(2)
      ..write(obj.isExpanded)
      ..writeByte(3)
      ..write(obj.plannedDate)
      ..writeByte(4)
      ..write(obj.completed)
      ..writeByte(5)
      ..write(obj.stepType)
      ..writeByte(6)
      ..write(obj.totalSteps)
      ..writeByte(7)
      ..write(obj.completedSteps)
      ..writeByte(8)
      ..write(obj.id)
      ..writeByte(9)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
