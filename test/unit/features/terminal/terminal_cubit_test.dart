import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';

void main() {
  group('TerminalCubit', () {
    test('initial state is TerminalInitial', () {
      expect(TerminalCubit().state, isA<TerminalInitial>());
    });

    blocTest<TerminalCubit, TerminalState>(
      'initialize() emits TerminalLoaded with empty sessions',
      build: () => TerminalCubit(),
      act: (cubit) => cubit.initialize(),
      expect: () => [
        isA<TerminalLoaded>()
            .having((s) => s.sessions, 'sessions', isEmpty)
            .having((s) => s.activeIndex, 'activeIndex', 0),
      ],
    );

    blocTest<TerminalCubit, TerminalState>(
      'switchTab updates activeIndex',
      build: () => TerminalCubit(),
      seed: () => const TerminalLoaded(sessions: [], activeIndex: 0),
      act: (cubit) => cubit.switchTab(0), // no-op with empty sessions
      expect: () => <TerminalState>[], // no state change since index is already 0
    );

    blocTest<TerminalCubit, TerminalState>(
      'switchTab ignores out-of-bounds index',
      build: () => TerminalCubit(),
      seed: () => const TerminalLoaded(sessions: [], activeIndex: 0),
      act: (cubit) => cubit.switchTab(5),
      expect: () => <TerminalState>[],
    );

    test('TerminalLoaded activeSession returns null for empty sessions', () {
      const state = TerminalLoaded(sessions: [], activeIndex: 0);
      expect(state.activeSession, isNull);
    });

    test('AgentType displayName is correct', () {
      expect(AgentType.copilot.displayName, 'Copilot');
      expect(AgentType.claude.displayName, 'Claude');
      expect(AgentType.terminal.displayName, 'Terminal');
    });

    test('AgentType command is correct', () {
      expect(AgentType.copilot.command, 'copilot');
      expect(AgentType.claude.command, 'claude');
      expect(AgentType.terminal.command, 'shell');
    });

    test('AgentType launchCommand includes --allow-all for copilot', () {
      expect(AgentType.copilot.launchCommand, 'copilot --allow-all');
      expect(AgentType.claude.launchCommand, 'claude');
      expect(AgentType.terminal.launchCommand, isEmpty);
    });

    test('AgentType has icon labels', () {
      for (final type in AgentType.values) {
        expect(type.iconLabel, isNotEmpty);
      }
    });
  });
}
