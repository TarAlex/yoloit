import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/diff_card.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/review_card_props_builder.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';

/// Mindmap diff card — uses the same presentation widget as the browser.
class DiffNode extends StatelessWidget {
  const DiffNode({super.key, required this.data});
  final DiffNodeData data;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewCubit, ReviewState>(
      builder: (context, state) => DiffCard(
        props: buildDiffCardProps(
          repoPath: data.repoPath ?? '',
          repoName: data.repoName,
          reviewState: state,
        ),
      ),
    );
  }
}
