import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/ui/file_editor_panel.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';

/// A standalone file panel card with its own [FileEditorCubit].
/// Each "Open in Panel" action creates one of these so multiple files
/// can coexist as separate canvas cards without sharing editor state.
class FilePanelNode extends StatefulWidget {
  const FilePanelNode({super.key, required this.data});
  final FilePanelNodeData data;

  @override
  State<FilePanelNode> createState() => _FilePanelNodeState();
}

class _FilePanelNodeState extends State<FilePanelNode> {
  late final FileEditorCubit _cubit;
  bool _immersive = false;

  @override
  void initState() {
    super.initState();
    _cubit = FileEditorCubit();
    // Open the file asynchronously so the panel appears immediately and
    // then populates once the file is read from disk.
    _cubit.openFile(widget.data.filePath);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FileEditorCubit>.value(
      value: _cubit,
      child: FileEditorPanel(
        immersive: _immersive,
        hideTabBar: false,
        onToggleImmersive: _toggleImmersive,
      ),
    );
  }

  void _toggleImmersive() => setState(() => _immersive = !_immersive);
}
