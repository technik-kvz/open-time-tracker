import 'package:json_annotation/json_annotation.dart';

part 'projects_repository.g.dart';

abstract class ProjectsRepository {
  Future<List<Project>> list({
    String? userId,
    bool? active,
    int? pageSize,
    bool sortByName = false,
    bool assignedToUser = false,
  });
}

@JsonSerializable()
class Project {
  final String id;
  final String title;
  final String href;
  final DateTime? updatedAt;

  Project({
    required this.id,
    required this.title,
    required this.href,
    required this.updatedAt,
  });

  /// Connect the generated [_$ProjectFromJson] function to the `fromJson` factory.
  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

  /// Connect the generated [_$ProjectToJson] function to the `toJson` method.
  Map<String, dynamic> toJson() => _$ProjectToJson(this);
}
