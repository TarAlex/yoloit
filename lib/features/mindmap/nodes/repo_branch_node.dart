import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/repo_branch_card.dart';

class RepoNode extends StatelessWidget {
  const RepoNode({super.key, required this.data});
  final RepoNodeData data;

  @override
  Widget build(BuildContext context) {
    return RepoCard(
      props: RepoCardProps(repoName: data.repoName, branch: data.branch),
    );
  }
}

class BranchNode extends StatelessWidget {
  const BranchNode({super.key, required this.data});
  final BranchNodeData data;

  @override
  Widget build(BuildContext context) {
    return BranchCard(
      props: BranchCardProps(
        branch: data.branch,
        repoName: data.repoName,
        commitHash: data.commitHash,
      ),
    );
  }
}
