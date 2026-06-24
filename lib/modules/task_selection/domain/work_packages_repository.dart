import 'package:freezed_annotation/freezed_annotation.dart';

part 'work_packages_repository.g.dart';

abstract class WorkPackagesRepository {
  Future<List<WorkPackage>> list({
    String? projectId,
    int? pageSize,
    Set<int>? statuses,
    String? user,
  });
}

enum WorkPackageAssigneeType {
  user,
  group,
}

@JsonSerializable()
class WorkPackageAssignee {
  final WorkPackageAssigneeType type;
  final String title;

  const WorkPackageAssignee({
    required this.type,
    required this.title,
  });

  /// Connect the generated [_$WorkPackageAssigneeFromJson] function to the `fromJson` factory.
  factory WorkPackageAssignee.fromJson(Map<String, dynamic> json) => _$WorkPackageAssigneeFromJson(json);

  /// Connect the generated [_$WorkPackageAssigneeToJson] function to the `toJson` method.
  Map<String, dynamic> toJson() => _$WorkPackageAssigneeToJson(this);
}

@JsonSerializable()
class WorkPackage {
  int id;
  String subject;
  String href;
  String projectTitle;
  String projectHref;
  String priority;
  String status;
  WorkPackageAssignee assignee;

  WorkPackage({
    required this.id,
    required this.subject,
    required this.href,
    required this.projectTitle,
    required this.projectHref,
    required this.priority,
    required this.status,
    required this.assignee,
  });

  /// Connect the generated [_$WorkPackageFromJson] function to the `fromJson` factory.
  factory WorkPackage.fromJson(Map<String, dynamic> json) => _$WorkPackageFromJson(json);

  /// Connect the generated [_$WorkPackageToJson] function to the `toJson` method.
  Map<String, dynamic> toJson() => _$WorkPackageToJson(this);
}
