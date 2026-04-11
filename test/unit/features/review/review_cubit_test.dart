import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/review/models/review_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewCubit', () {
    test('initial state is ReviewInitial', () {
      expect(ReviewCubit().state, isA<ReviewInitial>());
    });

    blocTest<ReviewCubit, ReviewState>(
      'loadWorkspace emits ReviewLoaded',
      build: () => ReviewCubit(),
      act: (cubit) => cubit.loadWorkspace(['/tmp']),
      verify: (cubit) => expect(cubit.state, isA<ReviewLoaded>()),
    );

    blocTest<ReviewCubit, ReviewState>(
      'setViewMode switches between diff and file',
      build: () => ReviewCubit(),
      seed: () => const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        viewMode: ReviewViewMode.diff,
      ),
      act: (cubit) => cubit.setViewMode(ReviewViewMode.file),
      expect: () => [
        isA<ReviewLoaded>().having((s) => s.viewMode, 'viewMode', ReviewViewMode.file),
      ],
    );

    blocTest<ReviewCubit, ReviewState>(
      'toggleNode expands a real directory node',
      build: () => ReviewCubit(),
      act: (cubit) async {
        // Use a real directory that exists on the test machine
        final dir = Directory.systemTemp;
        cubit.emit(ReviewLoaded(
          fileTree: [
            FileTreeNode(name: dir.path.split('/').last, path: dir.path, isDirectory: true),
          ],
          changedFiles: const [],
        ));
        cubit.toggleNode(dir.path);
      },
      expect: () => [
        isA<ReviewLoaded>(), // seeded state
        isA<ReviewLoaded>().having(
          (s) => s.fileTree.first.isExpanded,
          'isExpanded after toggle',
          true,
        ),
      ],
    );

    blocTest<ReviewCubit, ReviewState>(
      'toggleNode collapses an expanded directory node',
      build: () => ReviewCubit(),
      act: (cubit) async {
        final dir = Directory.systemTemp;
        cubit.emit(ReviewLoaded(
          fileTree: [
            FileTreeNode(
              name: dir.path.split('/').last,
              path: dir.path,
              isDirectory: true,
              isExpanded: true,
            ),
          ],
          changedFiles: const [],
        ));
        cubit.toggleNode(dir.path);
      },
      expect: () => [
        isA<ReviewLoaded>(), // seeded
        isA<ReviewLoaded>().having(
          (s) => s.fileTree.first.isExpanded,
          'isExpanded after collapse',
          false,
        ),
      ],
    );

    test('ReviewLoaded copyWith preserves viewMode when not changed', () {
      const state = ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        viewMode: ReviewViewMode.file,
        selectedFilePath: '/some/path',
      );
      final copy = state.copyWith(isLoadingDiff: true);
      expect(copy.viewMode, ReviewViewMode.file);
      expect(copy.selectedFilePath, '/some/path');
      expect(copy.isLoadingDiff, true);
    });

    test('ReviewLoaded copyWith clearSelectedFile works', () {
      const state = ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        selectedFilePath: '/some/path',
      );
      final copy = state.copyWith(clearSelectedFile: true);
      expect(copy.selectedFilePath, isNull);
    });
  });
}
