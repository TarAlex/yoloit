import 'dart:io';

class FileViewerService {
  const FileViewerService._();
  static const FileViewerService instance = FileViewerService._();

  static const _maxFileSize = 2 * 1024 * 1024; // 2MB

  Future<FileViewResult> readFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return const FileViewResult.error('File not found');
      }
      final stat = file.statSync();
      if (stat.size > _maxFileSize) {
        return const FileViewResult.error('File too large to display (>2MB)');
      }
      final content = await file.readAsString();
      final language = _detectLanguage(path);
      return FileViewResult.success(content: content, language: language);
    } catch (e) {
      return FileViewResult.error(e.toString());
    }
  }

  String _detectLanguage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'dart' => 'dart',
      'js' || 'jsx' => 'javascript',
      'ts' || 'tsx' => 'typescript',
      'py' => 'python',
      'rs' => 'rust',
      'go' => 'go',
      'java' => 'java',
      'kt' => 'kotlin',
      'swift' => 'swift',
      'c' || 'h' => 'c',
      'cpp' || 'cc' || 'cxx' || 'hpp' => 'cpp',
      'cs' => 'csharp',
      'rb' => 'ruby',
      'php' => 'php',
      'html' || 'htm' => 'html',
      'css' => 'css',
      'scss' || 'sass' => 'scss',
      'json' => 'json',
      'yaml' || 'yml' => 'yaml',
      'xml' => 'xml',
      'md' || 'markdown' => 'markdown',
      'sh' || 'bash' || 'zsh' => 'bash',
      'sql' => 'sql',
      'toml' => 'toml',
      _ => 'plaintext',
    };
  }
}

class FileViewResult {
  const FileViewResult._({this.content, this.language, this.error});

  const FileViewResult.success({required String content, required String language})
      : this._(content: content, language: language);

  const FileViewResult.error(String error) : this._(error: error);

  final String? content;
  final String? language;
  final String? error;

  bool get isSuccess => error == null;
}
