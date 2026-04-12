import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';

AgentSession _makeSession({
  String id = 's1',
  Map<String, String>? worktreeContexts,
}) {
  return AgentSession(
    id: id,
    type: AgentType.copilot,
    workspacePath: '/project',
    workspaceId: 'ws_1',
    worktreeContexts: worktreeContexts,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentSession.worktreeContexts', () {
    test('worktreeContexts defaults to null when not provided', () {
      final session = _makeSession();
      expect(session.worktreeContexts, isNull);
    });

    test('worktreeContexts is stored when provided in constructor', () {
      final contexts = {'/repo/path': '/worktree/path'};
      final session = _makeSession(worktreeContexts: contexts);
      expect(session.worktreeContexts, equals(contexts));
    });

    test('worktreeContexts stores all entries when multiple repos are provided', () {
      final contexts = {
        '/repo/a': '/worktree/a-branch',
        '/repo/b': '/worktree/b-branch',
      };
      final session = _makeSession(worktreeContexts: contexts);
      expect(session.worktreeContexts, hasLength(2));
      expect(session.worktreeContexts!['/repo/a'], equals('/worktree/a-branch'));
      expect(session.worktreeContexts!['/repo/b'], equals('/worktree/b-branch'));
    });

    test('copyWith with new worktreeContexts replaces the value', () {
      final original = _makeSession(worktreeContexts: {'/repo': '/old-worktree'});
      final updated = original.copyWith(
        worktreeContexts: {'/repo': '/new-worktree'},
      );

      expect(updated.worktreeContexts!['/repo'], equals('/new-worktree'));
      expect(original.worktreeContexts!['/repo'], equals('/old-worktree'));
    });

    test('copyWith without worktreeContexts preserves existing value', () {
      final contexts = {'/repo': '/worktree/path'};
      final original = _makeSession(worktreeContexts: contexts);
      final updated = original.copyWith(status: AgentStatus.live);

      expect(updated.worktreeContexts, equals(contexts));
    });

    test('copyWith without worktreeContexts preserves null value', () {
      final original = _makeSession();
      final updated = original.copyWith(status: AgentStatus.live);

      expect(updated.worktreeContexts, isNull);
    });

    test('copyWith preserves worktreeContexts when other fields are changed', () {
      final contexts = {'/repo/x': '/path/x', '/repo/y': '/path/y'};
      final original = _makeSession(worktreeContexts: contexts);
      final updated = original.copyWith(
        customName: 'my-session',
        status: AgentStatus.idle,
      );

      expect(updated.worktreeContexts, equals(contexts));
      expect(updated.customName, equals('my-session'));
    });

    group('Equatable props', () {
      test('two sessions with same worktreeContexts are equal', () {
        final s1 = _makeSession(worktreeContexts: {'/repo': '/wt'});
        final s2 = _makeSession(worktreeContexts: {'/repo': '/wt'});

        expect(s1, equals(s2));
        expect(s1.props, equals(s2.props));
      });

      test('two sessions with different worktreeContexts are NOT equal', () {
        final s1 = _makeSession(worktreeContexts: {'/repo': '/wt-a'});
        final s2 = _makeSession(worktreeContexts: {'/repo': '/wt-b'});

        expect(s1, isNot(equals(s2)));
      });

      test('session with worktreeContexts != session without worktreeContexts', () {
        final s1 = _makeSession(worktreeContexts: {'/repo': '/wt'});
        final s2 = _makeSession();

        expect(s1, isNot(equals(s2)));
      });

      test('worktreeContexts is included in props list', () {
        final contexts = {'/repo': '/wt'};
        final session = _makeSession(worktreeContexts: contexts);

        expect(session.props, contains(contexts));
      });

      test('two sessions with null worktreeContexts are equal', () {
        final s1 = _makeSession();
        final s2 = _makeSession();

        expect(s1, equals(s2));
      });

      test('props includes all expected fields including worktreeContexts', () {
        final contexts = {'/repo': '/wt'};
        final session = AgentSession(
          id: 'test-id',
          type: AgentType.claude,
          workspacePath: '/path',
          workspaceId: 'ws',
          worktreeContexts: contexts,
        );

        // Verify worktreeContexts is at the end of props (per implementation)
        expect(session.props.last, equals(contexts));
      });
    });
  });
}
