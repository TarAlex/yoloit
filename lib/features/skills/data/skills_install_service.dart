import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yoloit/core/platform/platform_dirs.dart';
import 'package:yoloit/features/skills/models/skill_entry.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';

/// Handles skill installation and workspace skill symlink management.
///
/// Install destinations:
///   Global store:      ~/.config/yoloit/skills/{skill-id}/
///   Claude pattern:    {workspaceDir}/.agents/skills/{skill-id} -> global store
///   Copilot pattern:   {workspaceDir}/.github/copilot/{skill-id} -> global store
///   Repo install:      {repoPath}/.agents/skills/{skill-id}/  (copy)
class SkillsInstallService {
  SkillsInstallService._();
  static final instance = SkillsInstallService._();

  String get _skillsDir => PlatformDirs.instance.skillsDir;

  String _claudeSkillsPath(String workspaceDir) =>
      p.join(workspaceDir, '.agents', 'skills');

  String _copilotSkillsPath(String workspaceDir) =>
      p.join(workspaceDir, '.github', 'copilot');

  // ── Install ─────────────────────────────────────────────────────────────────

  /// Installs a GitHub-sourced skill into the global skills dir.
  ///
  /// For flutter/skills: downloads the skill via gh CLI if available,
  /// otherwise clones the skill subdirectory.
  Future<SkillInstallResult> installGithubSkill(SkillEntry skill) async {
    final dest = Directory(p.join(_skillsDir, skill.id));
    if (await dest.exists()) {
      return SkillInstallResult.alreadyInstalled(skill.id);
    }

    // Try gh CLI first (fastest), fall back to git sparse checkout.
    final ghResult = await _tryGhDownload(skill);
    if (ghResult != null) return ghResult;

    return SkillInstallResult.error(
      skill.id,
      'Could not install skill. Ensure "gh" (GitHub CLI) is installed.\n'
      'Manual: gh skill install ${skill.id} or clone from ${skill.source}',
    );
  }

  Future<SkillInstallResult?> _tryGhDownload(SkillEntry skill) async {
    // Use gh api to download the skill folder from github
    // flutter/skills stores each skill as a directory with SKILL.md
    final parts = skill.source.split('/');
    if (parts.length < 2) return null;

    final owner = parts[0];
    final repo = parts[1];

    try {
      await Directory(_skillsDir).create(recursive: true);
      // Use git sparse-checkout to get just the skill folder
      final result = await Process.run('git', [
        'clone',
        '--depth=1',
        '--filter=blob:none',
        '--sparse',
        'https://github.com/$owner/$repo.git',
        p.join(_skillsDir, '_tmp_${skill.id}'),
      ]);
      if (result.exitCode != 0) return null;

      final tmpDir = Directory(p.join(_skillsDir, '_tmp_${skill.id}'));
      await Process.run('git', ['sparse-checkout', 'set', skill.id],
          workingDirectory: tmpDir.path);
      await Process.run('git', ['checkout'], workingDirectory: tmpDir.path);

      final srcSkillDir = Directory(p.join(tmpDir.path, skill.id));
      if (await srcSkillDir.exists()) {
        await _copyDirectory(srcSkillDir, Directory(p.join(_skillsDir, skill.id)));
      } else {
        // Some repos store skills at root level as SKILL.md
        final skillMd = File(p.join(tmpDir.path, 'SKILL.md'));
        if (await skillMd.exists()) {
          final dest = await Directory(p.join(_skillsDir, skill.id)).create(recursive: true);
          await skillMd.copy(p.join(dest.path, 'SKILL.md'));
        }
      }
      await tmpDir.delete(recursive: true);
      return SkillInstallResult.success(skill.id);
    } catch (e) {
      // Clean up tmp on error
      final tmpDir = Directory(p.join(_skillsDir, '_tmp_${skill.id}'));
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      return null;
    }
  }

  /// Runs an install script for script-based skills.
  /// Opens an interactive terminal session since scripts may need TTY.
  Future<SkillInstallResult> runInstallScript(SkillEntry skill) async {
    // Return the command for the caller to run in a terminal session.
    // The actual execution is done via PlatformLauncher to get an interactive shell.
    return SkillInstallResult.requiresTerminal(skill.id, skill.installCommand ?? '');
  }

  // ── Workspace symlink management ────────────────────────────────────────────

  /// Syncs skill symlinks for a workspace based on its enabledSkills list.
  /// Creates/removes symlinks in both Claude (.agents/skills/) and Copilot (.github/copilot/) paths.
  Future<void> syncWorkspaceSkills(Workspace workspace) async {
    final claudePath = _claudeSkillsPath(workspace.workspaceDir);
    final copilotPath = _copilotSkillsPath(workspace.workspaceDir);

    await _syncSkillLinks(
      skillsDir: claudePath,
      enabledSkillIds: workspace.enabledSkills,
      globalSkillsDir: _skillsDir,
    );

    await _syncSkillLinks(
      skillsDir: copilotPath,
      enabledSkillIds: workspace.enabledSkills,
      globalSkillsDir: _skillsDir,
      linkStyle: _LinkStyle.copilot,
    );
  }

  Future<void> _syncSkillLinks({
    required String skillsDir,
    required List<String> enabledSkillIds,
    required String globalSkillsDir,
    _LinkStyle linkStyle = _LinkStyle.claude,
  }) async {
    final dir = Directory(skillsDir);
    await dir.create(recursive: true);

    final desired = <String>{};
    for (final skillId in enabledSkillIds) {
      final globalSkillPath = p.join(globalSkillsDir, skillId);
      if (await Directory(globalSkillPath).exists()) {
        desired.add(skillId);
      }
    }

    // Remove stale skill links
    await for (final entity in dir.list()) {
      if (entity is Link) {
        final name = p.basename(entity.path);
        if (!desired.contains(name)) {
          await entity.delete();
        }
      }
    }

    // Create missing skill links
    for (final skillId in desired) {
      final linkPath = p.join(skillsDir, skillId);
      final link = Link(linkPath);
      if (!await link.exists()) {
        final globalSkillPath = p.join(globalSkillsDir, skillId);
        if (linkStyle == _LinkStyle.copilot) {
          // For Copilot: link the SKILL.md file directly
          final skillMd = File(p.join(globalSkillPath, 'SKILL.md'));
          if (await skillMd.exists()) {
            await Directory(linkPath).create(recursive: true);
            final mdLink = Link(p.join(linkPath, 'SKILL.md'));
            if (!await mdLink.exists()) {
              await mdLink.create(skillMd.path);
            }
          }
        } else {
          // Claude pattern: symlink entire skill directory
          await link.create(globalSkillPath);
        }
      }
    }
  }

  // ── Install to specific repo ─────────────────────────────────────────────────

  /// Copies (not symlinks) a skill into a specific repo path.
  /// Creates {repoPath}/.agents/skills/{skillId}/SKILL.md
  Future<SkillInstallResult> installSkillToRepo(SkillEntry skill, String repoPath) async {
    final globalSkillPath = Directory(p.join(_skillsDir, skill.id));
    if (!await globalSkillPath.exists()) {
      return SkillInstallResult.error(
        skill.id,
        'Skill not installed globally. Install it first from the Skills Store.',
      );
    }

    final destPath = p.join(repoPath, '.agents', 'skills', skill.id);
    final dest = Directory(destPath);
    if (await dest.exists()) {
      return SkillInstallResult.alreadyInstalled(skill.id);
    }

    try {
      await _copyDirectory(globalSkillPath, dest);
      return SkillInstallResult.success(skill.id);
    } catch (e) {
      return SkillInstallResult.error(skill.id, e.toString());
    }
  }

  // ── Uninstall ────────────────────────────────────────────────────────────────

  /// Removes a skill from the global skills dir and all workspace symlinks.
  Future<void> uninstallGlobalSkill(String skillId, List<Workspace> workspaces) async {
    // Remove from all workspace symlinks first
    for (final ws in workspaces) {
      final claudeLink = Link(p.join(_claudeSkillsPath(ws.workspaceDir), skillId));
      if (await claudeLink.exists()) await claudeLink.delete();
      final copilotDir = Directory(p.join(_copilotSkillsPath(ws.workspaceDir), skillId));
      if (await copilotDir.exists()) await copilotDir.delete(recursive: true);
    }

    // Remove global copy
    final globalSkillDir = Directory(p.join(_skillsDir, skillId));
    if (await globalSkillDir.exists()) {
      await globalSkillDir.delete(recursive: true);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _copyDirectory(Directory src, Directory dest) async {
    await dest.create(recursive: true);
    await for (final entity in src.list(recursive: false)) {
      final destPath = p.join(dest.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(destPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(destPath));
      }
    }
  }
}

enum _LinkStyle { claude, copilot }

// ── SkillInstallResult ────────────────────────────────────────────────────────

class SkillInstallResult {
  const SkillInstallResult._({
    required this.skillId,
    required this.status,
    this.message,
  });

  final String skillId;
  final SkillInstallStatus status;
  final String? message;

  factory SkillInstallResult.success(String skillId) =>
      SkillInstallResult._(skillId: skillId, status: SkillInstallStatus.success);

  factory SkillInstallResult.alreadyInstalled(String skillId) =>
      SkillInstallResult._(skillId: skillId, status: SkillInstallStatus.alreadyInstalled);

  factory SkillInstallResult.error(String skillId, String message) =>
      SkillInstallResult._(skillId: skillId, status: SkillInstallStatus.error, message: message);

  factory SkillInstallResult.requiresTerminal(String skillId, String command) =>
      SkillInstallResult._(
        skillId: skillId,
        status: SkillInstallStatus.requiresTerminal,
        message: command,
      );

  bool get isSuccess =>
      status == SkillInstallStatus.success ||
      status == SkillInstallStatus.alreadyInstalled;
}

enum SkillInstallStatus { success, alreadyInstalled, error, requiresTerminal }
