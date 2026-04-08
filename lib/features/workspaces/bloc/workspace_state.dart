import 'package:equatable/equatable.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';

abstract class WorkspaceState extends Equatable {
  const WorkspaceState();

  @override
  List<Object?> get props => [];
}

class WorkspaceInitial extends WorkspaceState {
  const WorkspaceInitial();
}

class WorkspaceLoading extends WorkspaceState {
  const WorkspaceLoading();
}

class WorkspaceLoaded extends WorkspaceState {
  const WorkspaceLoaded({
    required this.workspaces,
    this.activeWorkspaceId,
  });

  final List<Workspace> workspaces;
  final String? activeWorkspaceId;

  Workspace? get activeWorkspace =>
      workspaces.where((w) => w.id == activeWorkspaceId).firstOrNull;

  WorkspaceLoaded copyWith({
    List<Workspace>? workspaces,
    String? activeWorkspaceId,
    bool clearActive = false,
  }) {
    return WorkspaceLoaded(
      workspaces: workspaces ?? this.workspaces,
      activeWorkspaceId: clearActive ? null : (activeWorkspaceId ?? this.activeWorkspaceId),
    );
  }

  @override
  List<Object?> get props => [workspaces, activeWorkspaceId];
}

class WorkspaceError extends WorkspaceState {
  const WorkspaceError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
