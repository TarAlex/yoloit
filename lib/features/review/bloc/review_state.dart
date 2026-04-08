import 'package:equatable/equatable.dart';
import 'package:yoloit/features/review/models/review_models.dart';

enum ReviewViewMode { diff, file }

abstract class ReviewState extends Equatable {
  const ReviewState();

  @override
  List<Object?> get props => [];
}

class ReviewInitial extends ReviewState {
  const ReviewInitial();
}

class ReviewLoaded extends ReviewState {
  const ReviewLoaded({
    required this.fileTree,
    required this.changedFiles,
    this.selectedFilePath,
    this.diffHunks = const [],
    this.fileContent,
    this.fileLanguage,
    this.viewMode = ReviewViewMode.diff,
    this.isLoadingDiff = false,
    this.isLoadingFile = false,
    this.prStatus,
  });

  final List<FileTreeNode> fileTree;
  final List<FileChange> changedFiles;
  final String? selectedFilePath;
  final List<DiffHunk> diffHunks;
  final String? fileContent;
  final String? fileLanguage;
  final ReviewViewMode viewMode;
  final bool isLoadingDiff;
  final bool isLoadingFile;
  final PrStatus? prStatus;

  ReviewLoaded copyWith({
    List<FileTreeNode>? fileTree,
    List<FileChange>? changedFiles,
    String? selectedFilePath,
    List<DiffHunk>? diffHunks,
    String? fileContent,
    String? fileLanguage,
    ReviewViewMode? viewMode,
    bool? isLoadingDiff,
    bool? isLoadingFile,
    PrStatus? prStatus,
    bool clearSelectedFile = false,
    bool clearFileContent = false,
  }) {
    return ReviewLoaded(
      fileTree: fileTree ?? this.fileTree,
      changedFiles: changedFiles ?? this.changedFiles,
      selectedFilePath: clearSelectedFile ? null : (selectedFilePath ?? this.selectedFilePath),
      diffHunks: diffHunks ?? this.diffHunks,
      fileContent: clearFileContent ? null : (fileContent ?? this.fileContent),
      fileLanguage: fileLanguage ?? this.fileLanguage,
      viewMode: viewMode ?? this.viewMode,
      isLoadingDiff: isLoadingDiff ?? this.isLoadingDiff,
      isLoadingFile: isLoadingFile ?? this.isLoadingFile,
      prStatus: prStatus ?? this.prStatus,
    );
  }

  @override
  List<Object?> get props => [
        fileTree,
        changedFiles,
        selectedFilePath,
        diffHunks,
        fileContent,
        fileLanguage,
        viewMode,
        isLoadingDiff,
        isLoadingFile,
        prStatus,
      ];
}
