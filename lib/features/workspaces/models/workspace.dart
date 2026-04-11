import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class Workspace extends Equatable {
  const Workspace({
    required this.id,
    required this.name,
    required this.paths,
    this.gitBranch,
    this.addedLines = 0,
    this.removedLines = 0,
    this.isActive = false,
    this.color,
  });

  final String id;
  final String name;
  /// Ordered list of referenced folder paths. First path is the "primary" one
  /// used for git info display.
  final List<String> paths;
  final String? gitBranch;
  final int addedLines;
  final int removedLines;
  final bool isActive;
  /// User-chosen accent color for this workspace (null = use theme default)
  final Color? color;

  /// Primary path (first in list) — used for git operations and display.
  /// Returns empty string if no paths exist.
  String get path => paths.isNotEmpty ? paths.first : '';

  /// The internal workspace directory where symlinks to all paths live.
  /// Copilot/Claude are launched from here and can see all repos.
  String get workspaceDir {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, '.config', 'yoloit', 'workspaces', id);
  }

  Workspace copyWith({
    String? name,
    List<String>? paths,
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
      paths: paths ?? this.paths,
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
        'paths': paths,
        // legacy compat: write 'path' too so older builds can still read it
        'path': paths.isNotEmpty ? paths.first : '',
        'gitBranch': gitBranch,
        'addedLines': addedLines,
        'removedLines': removedLines,
        'colorValue': color?.value,
      };

  factory Workspace.fromJson(Map<String, dynamic> json) {
    // Support both new 'paths' list and legacy 'path' string.
    final List<String> paths;
    if (json['paths'] is List) {
      paths = (json['paths'] as List).cast<String>();
    } else if (json['path'] is String && (json['path'] as String).isNotEmpty) {
      paths = [json['path'] as String];
    } else {
      paths = [];
    }
    return Workspace(
      id: json['id'] as String,
      name: json['name'] as String,
      paths: paths,
      gitBranch: json['gitBranch'] as String?,
      addedLines: (json['addedLines'] as int?) ?? 0,
      removedLines: (json['removedLines'] as int?) ?? 0,
      color: json['colorValue'] != null
          ? Color(json['colorValue'] as int)
          : null,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, paths, gitBranch, addedLines, removedLines, isActive, color];
}
