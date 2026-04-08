enum AgentType {
  copilot('Copilot', 'gh copilot'),
  claude('Claude', 'claude');

  const AgentType(this.displayName, this.command);
  final String displayName;
  final String command;

  String get iconLabel {
    switch (this) {
      case AgentType.copilot:
        return '⊕';
      case AgentType.claude:
        return '✦';
    }
  }
}
