import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/collaboration/desktop/repo_directory_listing.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_cubit.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/file_tree_card.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/review_card_props_builder.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';

/// Mindmap file-tree card — uses the same presentation widget as the browser.
class FileTreeNode extends StatelessWidget {
  const FileTreeNode({super.key, required this.data});
  final FileTreeNodeData data;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewCubit, ReviewState>(
      builder: (context, state) => FileTreeCard(
        props: buildFileTreeCardProps(
          repoPath: data.repoPath ?? '',
          repoName: data.repoName,
          reviewState: state,
          listDirectory: listRepoDir,
        ),
        onToggle: (path) => context.read<ReviewCubit>().toggleNode(path),
        onSelect: (path) => context.read<FileEditorCubit>().openFile(path),
        onNewFolder: (parentPath) => _createNewFolder(context, parentPath),
        onShowInFinder: (path) => Process.run('open', ['-R', path]),
        onOpenInPanel: (path) => _openInPanel(context, path),
      ),
    );
  }

  Future<void> _createNewFolder(BuildContext context, String parentPath) async {
    // Ask user for the new folder name.
    final navigator = Navigator.of(context, rootNavigator: true);
    final reviewCubit = context.read<ReviewCubit>();
    final ctrl = TextEditingController();

    final name = await showDialog<String>(
      context: navigator.context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2A),
        title: const Text('New Folder',
            style: TextStyle(color: Color(0xFFCECEEE), fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFCECEEE), fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: const TextStyle(color: Color(0xFF6B7898), fontSize: 13),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: const Color(0xFF0F1117),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF2A3040)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF7C3AED)),
            ),
          ),
          onSubmitted: (v) => Navigator.of(dialogCtx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7898), fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text.trim()),
            child: const Text('Create',
                style: TextStyle(color: Color(0xFF7C3AED), fontSize: 12)),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (name == null || name.isEmpty) return;

    final newPath = '$parentPath/$name';
    await Directory(newPath).create(recursive: true);

    // Expand the parent so the new folder is visible.
    if (!reviewCubit.isClosed) {
      reviewCubit.toggleNode(parentPath);   // expand (or re-expand)
    }
  }

  void _openInPanel(BuildContext context, String path) {
    final nodeId = 'panel:${path.hashCode}';
    if (!context.mounted) return;
    context.read<MindMapCubit>().openFileAsPanel(
      id: nodeId,
      filePath: path,
    );
  }
}
