class WorktreeEntry {
  const WorktreeEntry({
    required this.path,
    this.branch,
    this.commit,
    required this.isMain,
    required this.isLocked,
    required this.isBare,
  });

  final String path;
  final String? branch;
  final String? commit;
  final bool isMain;
  final bool isLocked;
  final bool isBare;
}
