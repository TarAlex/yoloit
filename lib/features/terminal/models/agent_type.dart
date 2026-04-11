enum AgentType {
  copilot('Copilot', 'copilot', 'copilot --allow-all'),
  claude('Claude', 'claude', 'claude'),
  gemini('Gemini', 'gemini', 'gemini'),
  cursor('Cursor', 'cursor', 'cursor-agent'),
  terminal('Terminal', 'shell', '');

  const AgentType(this.displayName, this.command, this.launchCommand);
  final String displayName;
  /// Short label shown in the terminal header bar.
  final String command;
  /// Full command sent automatically when the session starts. Empty = plain shell.
  final String launchCommand;

  String get iconLabel {
    switch (this) {
      case AgentType.copilot:
        return '⊕';
      case AgentType.claude:
        return '✦';
      case AgentType.gemini:
        return '✦';
      case AgentType.cursor:
        return '◈';
      case AgentType.terminal:
        return '>_';
    }
  }
}
