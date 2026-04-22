/// Fine-grained phase of a Copilot agent session, driven by hook events.
///
/// Mirrors the superset pattern: typed state instead of magic strings.
/// null = idle (session running but agent not actively working).
sealed class AgentPhase {
  const AgentPhase();

  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Agent is processing a user prompt (userPromptSubmitted).
class ThinkingPhase extends AgentPhase {
  const ThinkingPhase();

  @override
  String toString() => 'thinking';
}

/// Agent is executing a tool (preToolUse).
class ToolPhase extends AgentPhase {
  const ToolPhase(this.toolName);

  final String toolName;

  @override
  bool operator ==(Object other) =>
      other is ToolPhase && other.toolName == toolName;

  @override
  int get hashCode => Object.hash(runtimeType, toolName);

  @override
  String toString() => 'tool:$toolName';
}

/// Agent finished — brief flash then auto-clears.
class DonePhase extends AgentPhase {
  const DonePhase();

  @override
  String toString() => 'done';
}

/// Agent encountered an error.
class ErrorPhase extends AgentPhase {
  const ErrorPhase();

  @override
  String toString() => 'error';
}
