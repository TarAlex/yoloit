import 'package:yoloit/core/services/git_service.dart';
import 'package:yoloit/features/review/models/review_models.dart';

class DiffService {
  const DiffService._();
  static const DiffService instance = DiffService._();

  Future<List<DiffHunk>> getDiff(String workspacePath, String filePath) async {
    final rawDiff = await GitService.instance.getDiff(workspacePath, filePath);
    return parseDiff(rawDiff);
  }

  List<DiffHunk> parseDiff(String rawDiff) {
    if (rawDiff.isEmpty) return [];

    final hunks = <DiffHunk>[];
    final lines = rawDiff.split('\n');

    DiffHunk? currentHunk;
    List<DiffLine> currentLines = [];
    int oldLineNum = 0;
    int newLineNum = 0;

    for (final line in lines) {
      if (line.startsWith('@@')) {
        // Save previous hunk
        if (currentHunk != null) {
          hunks.add(DiffHunk(
            header: currentHunk.header,
            lines: List.unmodifiable(currentLines),
            oldStart: currentHunk.oldStart,
            newStart: currentHunk.newStart,
          ));
        }
        // Parse hunk header: @@ -oldStart,oldCount +newStart,newCount @@
        final match = RegExp(r'@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@').firstMatch(line);
        oldLineNum = int.tryParse(match?.group(1) ?? '1') ?? 1;
        newLineNum = int.tryParse(match?.group(2) ?? '1') ?? 1;
        currentHunk = DiffHunk(
          header: line,
          lines: const [],
          oldStart: oldLineNum,
          newStart: newLineNum,
        );
        currentLines = [
          DiffLine(type: DiffLineType.header, content: line),
        ];
      } else if (line.startsWith('+') && !line.startsWith('+++')) {
        currentLines.add(DiffLine(
          type: DiffLineType.add,
          content: line.substring(1),
          newLineNum: newLineNum++,
        ));
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        currentLines.add(DiffLine(
          type: DiffLineType.remove,
          content: line.substring(1),
          oldLineNum: oldLineNum++,
        ));
      } else if (line.startsWith(' ')) {
        currentLines.add(DiffLine(
          type: DiffLineType.context,
          content: line.substring(1),
          oldLineNum: oldLineNum++,
          newLineNum: newLineNum++,
        ));
      }
    }

    if (currentHunk != null && currentLines.isNotEmpty) {
      hunks.add(DiffHunk(
        header: currentHunk.header,
        lines: List.unmodifiable(currentLines),
        oldStart: currentHunk.oldStart,
        newStart: currentHunk.newStart,
      ));
    }

    return hunks;
  }

  Future<List<FileChange>> getChangedFiles(String workspacePath) async {
    final statuses = await GitService.instance.getStatus(workspacePath);
    return statuses.map((s) {
      FileChangeStatus status;
      if (s.indexStatus == '?' && s.workingTreeStatus == '?') {
        status = FileChangeStatus.untracked;
      } else if (s.indexStatus == 'A') {
        status = FileChangeStatus.added;
      } else if (s.indexStatus == 'D' || s.workingTreeStatus == 'D') {
        status = FileChangeStatus.deleted;
      } else if (s.indexStatus == 'R') {
        status = FileChangeStatus.renamed;
      } else {
        status = FileChangeStatus.modified;
      }
      return FileChange(
        path: s.path,
        status: status,
        isStaged: s.isStaged,
      );
    }).toList();
  }
}
