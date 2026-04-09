import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class RunConfig extends Equatable {
  const RunConfig({
    required this.id,
    required this.name,
    required this.command,
    this.workingDir,
    this.env = const {},
    this.color,
    this.isFlutterRun = false,
  });

  final String id;
  final String name;
  final String command;
  final String? workingDir;
  final Map<String, String> env;
  final Color? color;
  final bool isFlutterRun;

  RunConfig copyWith({
    String? id,
    String? name,
    String? command,
    String? workingDir,
    bool clearWorkingDir = false,
    Map<String, String>? env,
    Color? color,
    bool clearColor = false,
    bool? isFlutterRun,
  }) {
    return RunConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      workingDir: clearWorkingDir ? null : (workingDir ?? this.workingDir),
      env: env ?? this.env,
      color: clearColor ? null : (color ?? this.color),
      isFlutterRun: isFlutterRun ?? this.isFlutterRun,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        'workingDir': workingDir,
        'env': env,
        'color': color?.toARGB32(),
        'isFlutterRun': isFlutterRun,
      };

  factory RunConfig.fromJson(Map<String, dynamic> json) => RunConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        command: json['command'] as String,
        workingDir: json['workingDir'] as String?,
        env: (json['env'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      color: json['color'] != null ? Color(json['color'] as int) : null,
        isFlutterRun: json['isFlutterRun'] as bool? ?? false,
      );

  static RunConfig flutterRunMacos(String workspacePath) => const RunConfig(
        id: 'preset_flutter_run_macos',
        name: 'Flutter Run (macOS)',
        command: 'flutter run -d macos --debug',
        color: Color(0xFF54C5F8),
        isFlutterRun: true,
      );

  static RunConfig flutterTest() => const RunConfig(
        id: 'preset_flutter_test',
        name: 'Flutter Test',
        command: 'flutter test',
        color: Color(0xFF00FF9F),
      );

  static RunConfig flutterBuildMacos() => const RunConfig(
        id: 'preset_flutter_build_macos',
        name: 'Flutter Build (macOS)',
        command: 'flutter build macos',
        color: Color(0xFFFFD700),
      );

  @override
  List<Object?> get props =>
      [id, name, command, workingDir, env, color?.toARGB32(), isFlutterRun];
}


