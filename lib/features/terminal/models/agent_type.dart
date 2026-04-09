enum AgentType {
  copilot('Copilot', 'gh copilot', 'gh copilot --allow-all'),
  claude('Claude', 'claude', 'claude');

  const AgentType(this.displayName, this.command, this.launchCommand);
  final String displayName;
  /// Short label shown in the terminal header bar.
  final String command;
  /// Full command sent automatically when the session starts.
  final String launchCommand;

  String get iconLabel {
    switch (this) {
      case AgentType.copilot:
        return '⊕';
      case AgentType.claude:
        return '✦';
    }
  }
}
