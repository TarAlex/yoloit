import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkspaceCubit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is WorkspaceInitial', () {
      final cubit = WorkspaceCubit();
      expect(cubit.state, const WorkspaceInitial());
      cubit.close();
    });

    blocTest<WorkspaceCubit, WorkspaceState>(
      'load() with empty prefs emits WorkspaceLoading then WorkspaceLoaded with empty list',
      build: () => WorkspaceCubit(),
      act: (cubit) => cubit.load(),
      expect: () => [
        const WorkspaceLoading(),
        isA<WorkspaceLoaded>().having((s) => s.workspaces, 'workspaces', isEmpty),
      ],
    );

    blocTest<WorkspaceCubit, WorkspaceState>(
      'load() restores persisted workspaces',
      setUp: () async {
        SharedPreferences.setMockInitialValues({
          'workspaces': [
            '{"id":"ws_1","name":"project","path":"/tmp/project","gitBranch":null,"addedLines":0,"removedLines":0}'
          ],
        });
      },
      build: () => WorkspaceCubit(),
      act: (cubit) => cubit.load(),
      expect: () => [
        const WorkspaceLoading(),
        isA<WorkspaceLoaded>().having(
          (s) => s.workspaces.first.name,
          'first workspace name',
          'project',
        ),
      ],
    );

    blocTest<WorkspaceCubit, WorkspaceState>(
      'removeWorkspace removes correct workspace',
      build: () => WorkspaceCubit(),
      seed: () => const WorkspaceLoaded(
        workspaces: [
          Workspace(id: 'ws_1', name: 'alpha', path: '/a'),
          Workspace(id: 'ws_2', name: 'beta', path: '/b'),
        ],
      ),
      act: (cubit) => cubit.removeWorkspace('ws_1'),
      expect: () => [
        isA<WorkspaceLoaded>().having(
          (s) => s.workspaces.map((w) => w.id).toList(),
          'remaining workspaces',
          ['ws_2'],
        ),
      ],
    );

    blocTest<WorkspaceCubit, WorkspaceState>(
      'setActive updates activeWorkspaceId',
      build: () => WorkspaceCubit(),
      seed: () => const WorkspaceLoaded(
        workspaces: [
          Workspace(id: 'ws_1', name: 'alpha', path: '/a'),
          Workspace(id: 'ws_2', name: 'beta', path: '/b'),
        ],
      ),
      act: (cubit) => cubit.setActive('ws_2'),
      expect: () => [
        isA<WorkspaceLoaded>().having((s) => s.activeWorkspaceId, 'activeId', 'ws_2'),
      ],
    );

    blocTest<WorkspaceCubit, WorkspaceState>(
      'removeWorkspace clears activeWorkspaceId when active is removed',
      build: () => WorkspaceCubit(),
      seed: () => const WorkspaceLoaded(
        workspaces: [
          Workspace(id: 'ws_1', name: 'alpha', path: '/a'),
        ],
        activeWorkspaceId: 'ws_1',
      ),
      act: (cubit) => cubit.removeWorkspace('ws_1'),
      expect: () => [
        isA<WorkspaceLoaded>().having((s) => s.activeWorkspaceId, 'activeId', isNull),
      ],
    );

    test('WorkspaceLoaded.activeWorkspace returns correct workspace', () {
      const state = WorkspaceLoaded(
        workspaces: [
          Workspace(id: 'ws_1', name: 'alpha', path: '/a'),
          Workspace(id: 'ws_2', name: 'beta', path: '/b'),
        ],
        activeWorkspaceId: 'ws_2',
      );
      expect(state.activeWorkspace?.id, 'ws_2');
      expect(state.activeWorkspace?.name, 'beta');
    });

    test('WorkspaceLoaded.activeWorkspace returns null when no active', () {
      const state = WorkspaceLoaded(workspaces: [
        Workspace(id: 'ws_1', name: 'alpha', path: '/a'),
      ]);
      expect(state.activeWorkspace, isNull);
    });
  });
}
