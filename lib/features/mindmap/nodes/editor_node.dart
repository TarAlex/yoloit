import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/bloc/file_editor_state.dart';
import 'package:yoloit/features/editor/ui/file_editor_panel.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/editor_card.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/editor_card_props_builder.dart';

/// Mindmap editor card — uses the shared EditorCard shell and embeds the full
/// FileEditorPanel body so all editor functionality stays available.
class EditorNode extends StatefulWidget {
  const EditorNode({super.key, required this.data});
  final EditorNodeData data;

  @override
  State<EditorNode> createState() => _EditorNodeState();
}

class _EditorNodeState extends State<EditorNode> {
  bool _immersive = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileEditorCubit, FileEditorState>(
      builder: (context, state) => EditorCard(
        props: buildEditorCardProps(data: widget.data, editorState: state),
        immersive: _immersive,
        onSwitchTab: context.read<FileEditorCubit>().switchTab,
        onSave: () {
          context.read<FileEditorCubit>().saveFile();
        },
        onToggleImmersive: _toggleImmersive,
        body: FileEditorPanel(
          immersive: _immersive,
          hideTabBar: true,
          onToggleImmersive: _toggleImmersive,
        ),
      ),
    );
  }

  void _toggleImmersive() => setState(() => _immersive = !_immersive);
}
