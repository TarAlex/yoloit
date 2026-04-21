import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/collaboration/desktop/repo_directory_listing.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
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
      ),
    );
  }
}
