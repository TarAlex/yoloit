import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Workspace extends Equatable {
  const Workspace({
    required this.id,
    required this.name,
    required this.path,
    this.gitBranch,
    this.addedLines = 0,
    this.removedLines = 0,
    this.isActive = false,
    this.color,
  });

  final String id;
  final String name;
  final String path;
  final String? gitBranch;
  final int addedLines;
  final int removedLines;
  final bool isActive;
  /// User-chosen accent color for this workspace (null = use theme default)
  final Color? color;

  Workspace copyWith({
    String? name,
    String? path,
    String? gitBranch,
    int? addedLines,
    int? removedLines,
    bool? isActive,
    Color? color,
    bool clearColor = false,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      path: path ?? this.path,
      gitBranch: gitBranch ?? this.gitBranch,
      addedLines: addedLines ?? this.addedLines,
      removedLines: removedLines ?? this.removedLines,
      isActive: isActive ?? this.isActive,
      color: clearColor ? null : (color ?? this.color),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'gitBranch': gitBranch,
        'addedLines': addedLines,
        'removedLines': removedLines,
        'colorValue': color?.value,
      };

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        gitBranch: json['gitBranch'] as String?,
        addedLines: (json['addedLines'] as int?) ?? 0,
        removedLines: (json['removedLines'] as int?) ?? 0,
        color: json['colorValue'] != null
            ? Color(json['colorValue'] as int)
            : null,
      );

  @override
  List<Object?> get props =>
      [id, name, path, gitBranch, addedLines, removedLines, isActive, color];
}
