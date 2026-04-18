import 'package:equatable/equatable.dart';
import 'package:yoloit/features/skills/models/skill_entry.dart';
import 'package:yoloit/features/skills/models/skill_store_config.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';

abstract class SkillsState extends Equatable {
  const SkillsState();
  @override
  List<Object?> get props => [];
}

class SkillsInitial extends SkillsState {
  const SkillsInitial();
}

class SkillsLoading extends SkillsState {
  const SkillsLoading();
}

class SkillsLoaded extends SkillsState {
  const SkillsLoaded({
    required this.config,
    required this.skills,
    required this.workspaces,
    this.selectedStoreId,
    this.busySkillIds = const {},
    this.errorMessage,
    this.loadedFromRemote = false,
  });

  final SkillsStoreConfig config;
  final List<SkillEntry> skills;
  final List<Workspace> workspaces;

  /// Currently selected store filter (null = show all).
  final String? selectedStoreId;

  /// Skill IDs currently being installed/uninstalled.
  final Set<String> busySkillIds;

  final String? errorMessage;

  /// Whether the config was freshly fetched from GitHub this session.
  final bool loadedFromRemote;

  List<SkillEntry> get filteredSkills {
    if (selectedStoreId == null) return skills;
    return skills.where((s) => s.storeId == selectedStoreId || s.sourceType == SkillSourceType.local).toList();
  }

  List<SkillEntry> get installedSkills =>
      skills.where((s) => s.isInstalled).toList();

  bool isEnabledInWorkspace(String skillId, String workspaceId) {
    final ws = workspaces.where((w) => w.id == workspaceId).firstOrNull;
    return ws?.enabledSkills.contains(skillId) ?? false;
  }

  SkillsLoaded copyWith({
    SkillsStoreConfig? config,
    List<SkillEntry>? skills,
    List<Workspace>? workspaces,
    String? selectedStoreId,
    bool clearSelectedStore = false,
    Set<String>? busySkillIds,
    String? errorMessage,
    bool clearError = false,
    bool? loadedFromRemote,
  }) =>
      SkillsLoaded(
        config: config ?? this.config,
        skills: skills ?? this.skills,
        workspaces: workspaces ?? this.workspaces,
        selectedStoreId: clearSelectedStore ? null : (selectedStoreId ?? this.selectedStoreId),
        busySkillIds: busySkillIds ?? this.busySkillIds,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        loadedFromRemote: loadedFromRemote ?? this.loadedFromRemote,
      );

  @override
  List<Object?> get props => [config, skills, workspaces, selectedStoreId, busySkillIds, errorMessage, loadedFromRemote];
}

class SkillsError extends SkillsState {
  const SkillsError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
