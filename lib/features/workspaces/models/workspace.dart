import 'package:equatable/equatable.dart';

class Workspace extends Equatable {
  const Workspace({
    required this.id,
    required this.name,
    required this.path,
    this.gitBranch,
    this.addedLines = 0,
    this.removedLines = 0,
    this.isActive = false,
  });

  final String id;
  final String name;
  final String path;
  final String? gitBranch;
  final int addedLines;
  final int removedLines;
  final bool isActive;

  Workspace copyWith({
    String? name,
    String? path,
    String? gitBranch,
    int? addedLines,
    int? removedLines,
    bool? isActive,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      path: path ?? this.path,
      gitBranch: gitBranch ?? this.gitBranch,
      addedLines: addedLines ?? this.addedLines,
      removedLines: removedLines ?? this.removedLines,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'gitBranch': gitBranch,
        'addedLines': addedLines,
        'removedLines': removedLines,
      };

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        gitBranch: json['gitBranch'] as String?,
        addedLines: (json['addedLines'] as int?) ?? 0,
        removedLines: (json['removedLines'] as int?) ?? 0,
      );

  @override
  List<Object?> get props => [id, name, path, gitBranch, addedLines, removedLines, isActive];
}
