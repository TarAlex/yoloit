import 'package:equatable/equatable.dart';
import 'package:yoloit/features/runs/models/run_config.dart';

enum RunStatus { idle, running, stopped, failed }

class RunOutputLine extends Equatable {
  const RunOutputLine({
    required this.text,
    required this.isError,
    required this.timestamp,
  });

  final String text;
  final bool isError;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'text': text,
        'isError': isError,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory RunOutputLine.fromJson(Map<String, dynamic> j) => RunOutputLine(
        text: j['text'] as String,
        isError: j['isError'] as bool,
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
      );

  @override
  List<Object?> get props => [text, isError, timestamp];
}

class RunSession extends Equatable {
  const RunSession({
    required this.id,
    required this.config,
    required this.workspacePath,
    this.status = RunStatus.idle,
    this.output = const [],
    this.exitCode,
    this.startedAt,
  });

  final String id;
  final RunConfig config;
  final String workspacePath;
  final RunStatus status;
  final List<RunOutputLine> output;
  final int? exitCode;
  final DateTime? startedAt;

  RunSession copyWith({
    String? id,
    RunConfig? config,
    String? workspacePath,
    RunStatus? status,
    List<RunOutputLine>? output,
    int? exitCode,
    bool clearExitCode = false,
    DateTime? startedAt,
  }) {
    return RunSession(
      id: id ?? this.id,
      config: config ?? this.config,
      workspacePath: workspacePath ?? this.workspacePath,
      status: status ?? this.status,
      output: output ?? this.output,
      exitCode: clearExitCode ? null : (exitCode ?? this.exitCode),
      startedAt: startedAt ?? this.startedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'config': config.toJson(),
        'workspacePath': workspacePath,
        'status': status.name,
        'output': output.map((l) => l.toJson()).toList(),
        'exitCode': exitCode,
        'startedAt': startedAt?.millisecondsSinceEpoch,
      };

  factory RunSession.fromJson(Map<String, dynamic> j) => RunSession(
        id: j['id'] as String,
        config: RunConfig.fromJson(j['config'] as Map<String, dynamic>),
        workspacePath: j['workspacePath'] as String,
        status: RunStatus.values.firstWhere(
          (s) => s.name == (j['status'] as String? ?? 'stopped'),
          orElse: () => RunStatus.stopped,
        ),
        output: (j['output'] as List<dynamic>? ?? [])
            .map((e) => RunOutputLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        exitCode: j['exitCode'] as int?,
        startedAt: j['startedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['startedAt'] as int)
            : null,
      );

  @override
  List<Object?> get props => [id, status, output, exitCode];
}
