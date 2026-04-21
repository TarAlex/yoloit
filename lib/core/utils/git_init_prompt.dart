import 'dart:io';

import 'package:flutter/material.dart';

/// Checks whether [folderPath] contains a git repository.
/// If not, shows a dialog asking the user whether to run `git init`.
/// Always returns — the workspace is added regardless of the user's choice.
Future<void> maybePromptGitInit(BuildContext context, String folderPath) async {
  final gitDir = Directory('$folderPath/.git');
  if (gitDir.existsSync()) return; // already a git repo — nothing to do

  if (!context.mounted) return;

  final init = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF12151C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF2A3040)),
      ),
      title: const Text(
        'No Git Repository',
        style: TextStyle(color: Color(0xFFE8E8FF), fontSize: 14),
      ),
      content: Text(
        'The folder "${_basename(folderPath)}" is not a git repository.\n'
        'Initialize one here?',
        style: const TextStyle(color: Color(0xFFB0B0CC), fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Skip', style: TextStyle(color: Color(0xFF6B7898))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Initialize Git',
            style: TextStyle(color: Color(0xFF7C6BFF)),
          ),
        ),
      ],
    ),
  );

  if (init == true) {
    await Process.run('git', ['init', folderPath]);
  }
}

String _basename(String path) {
  final sep = path.contains('/') ? '/' : r'\';
  return path.split(sep).where((s) => s.isNotEmpty).last;
}
