import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/run_card.dart';
import 'package:yoloit/features/runs/bloc/run_cubit.dart';
import 'package:yoloit/features/runs/models/run_session.dart';

class RunNode extends StatelessWidget {
  const RunNode({super.key, required this.data});
  final RunNodeData data;

  @override
  Widget build(BuildContext context) {
    final session = data.session;
    return RunCard(
      props: RunCardProps(
        name: session.config.name,
        status: session.status.name,
        isRunning: session.status == RunStatus.running,
        lines: session.output
            .map((l) => OutputLine(text: l.text, isError: l.isError))
            .toList(),
      ),
      onCopy: () {
        final text = session.output.map((l) => l.text).join('\n');
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logs copied to clipboard'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            width: 220,
          ),
        );
      },
      onStart: () => context.read<RunCubit>().startRun(session.config),
      onStop: () => context.read<RunCubit>().stopRun(session.id),
      onRestart: () {
        final cubit = context.read<RunCubit>();
        if (session.status == RunStatus.running) cubit.stopRun(session.id);
        cubit.startRun(session.config);
      },
    );
  }
}
