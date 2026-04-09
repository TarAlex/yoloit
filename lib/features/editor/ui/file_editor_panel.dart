import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight_core.dart' show Mode;
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/swift.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/bloc/file_editor_state.dart';
import 'package:yoloit/features/editor/utils/file_type_utils.dart';
import 'package:yoloit/features/review/models/review_models.dart';

class FileEditorPanel extends StatefulWidget {
  const FileEditorPanel({super.key});

  @override
  State<FileEditorPanel> createState() => _FileEditorPanelState();
}

class _FileEditorPanelState extends State<FileEditorPanel> {
  /// One CodeController per open file path.
  final Map<String, CodeController> _controllers = {};
  /// Tracks which content was last loaded into each controller (to avoid loops).
  final Map<String, String> _loadedContent = {};
  double _fontSize = 13.0;
  double _scaleBase = 13.0;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  static Mode? _modeFor(String path) {
    final lang = FileTypeUtils.languageFor(path);
    return switch (lang) {
      'dart' => dart,
      'javascript' => javascript,
      'typescript' => typescript,
      'python' => python,
      'java' => java,
      'kotlin' => kotlin,
      'go' => go,
      'rust' => rust,
      'bash' => bash,
      'cpp' => cpp,
      'css' => css,
      'json' => json,
      'yaml' => yaml,
      'xml' => xml,
      'sql' => sql,
      'markdown' => markdown,
      'swift' => swift,
      _ => null,
    };
  }

  /// Returns the controller for [tab], creating it if needed.
  CodeController _controllerFor(EditorTab tab, BuildContext context) {
    if (!_controllers.containsKey(tab.filePath)) {
      final ctrl = CodeController(
        text: tab.content ?? '',
        language: _modeFor(tab.filePath),
      );
      _controllers[tab.filePath] = ctrl;
      _loadedContent[tab.filePath] = tab.content ?? '';
      ctrl.addListener(() {
        final text = ctrl.text;
        final cubit = context.read<FileEditorCubit>();
        final currentTab = cubit.state.activeTab;
        if (currentTab?.filePath == tab.filePath && text != currentTab?.content) {
          cubit.updateContent(text);
        }
      });
    } else {
      // Sync content if it was updated externally (e.g. initial load finished).
      final incoming = tab.content ?? '';
      if (_loadedContent[tab.filePath] != incoming) {
        _loadedContent[tab.filePath] = incoming;
        _controllers[tab.filePath]!.text = incoming;
      }
    }
    return _controllers[tab.filePath]!;
  }

  /// Dispose controllers for tabs that are no longer open.
  void _cleanupControllers(List<EditorTab> openTabs) {
    final openPaths = openTabs.map((t) => t.filePath).toSet();
    final toRemove = _controllers.keys.where((p) => !openPaths.contains(p)).toList();
    for (final path in toRemove) {
      _controllers.remove(path)?.dispose();
      _loadedContent.remove(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileEditorCubit, FileEditorState>(
      builder: (context, state) {
        _cleanupControllers(state.tabs);

        if (!state.isOpen) return _emptyState(context);

        final activeTab = state.activeTab!;
        CodeController? controller;
        if (!activeTab.isDiff && activeTab.content != null) {
          controller = _controllerFor(activeTab, context);
        } else if (!activeTab.isDiff) {
          controller = _controllerFor(activeTab, context);
        }

        return GestureDetector(
          onScaleStart: (d) => _scaleBase = _fontSize,
          onScaleUpdate: (d) {
            setState(() {
              _fontSize = (_scaleBase * d.scale).clamp(8.0, 32.0);
            });
          },
          child: Column(
            children: [
              _TabBar(state: state),
              Expanded(
                child: activeTab.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : activeTab.error != null
                        ? _ErrorView(message: activeTab.error!)
                        : activeTab.isDiff
                            ? _DiffBody(tab: activeTab)
                            : _EditorBody(tab: activeTab, codeController: controller!, fontSize: _fontSize),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.code, size: 40, color: AppColors.textMuted.withAlpha(60)),
            const SizedBox(height: 12),
            const Text(
              'Open a file to edit',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab bar ────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.state});

  final FileEditorState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: 36,
      color: colors.surface,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.tabs.length,
              itemBuilder: (context, i) => _Tab(
                tab: state.tabs[i],
                isActive: i == state.activeIndex,
                onTap: () => context.read<FileEditorCubit>().switchTab(i),
                onClose: () => context.read<FileEditorCubit>().closeTab(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  final EditorTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fileInfo = tab.isDiff ? null : FileTypeUtils.forPath(tab.filePath);
    final displayName = tab.isDiff
        ? '${tab.filePath.replaceFirst('diff:', '').split('/').last} (diff)'
        : tab.fileName;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200, minWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? colors.background : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.isDiff ? Icons.difference : fileInfo!.icon,
              size: 12,
              color: tab.isDiff ? AppColors.textMuted : fileInfo!.color,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                displayName,
                style: TextStyle(
                  color: isActive ? colors.primaryLight : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            _TabCloseButton(onClose: onClose),
          ],
        ),
      ),
    );
  }
}

class _TabCloseButton extends StatefulWidget {
  const _TabCloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_TabCloseButton> createState() => _TabCloseButtonState();
}

class _TabCloseButtonState extends State<_TabCloseButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onClose,
        child: SizedBox(
          width: 16,
          height: 16,
          child: Icon(
            Icons.close,
            size: 12,
            color: _hovering ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Error view ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.background,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Editor body ─────────────────────────────────────────────────────────────

class _EditorBody extends StatelessWidget {
  const _EditorBody({required this.tab, required this.codeController, this.fontSize = 13.0});

  final EditorTab tab;
  final CodeController codeController;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return CodeTheme(
      data: CodeThemeData(styles: _darkTheme),
      child: CodeField(
        controller: codeController,
        expands: true,
        wrap: false,
        textStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          height: 1.5,
        ),
        background: colors.background,
        gutterStyle: GutterStyle(
          width: 48,
          margin: 8,
          textStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
          background: colors.surfaceElevated,
        ),
      ),
    );
  }

  /// Dark syntax highlighting theme matching the app's dark palette.
  static const Map<String, TextStyle> _darkTheme = {
    'root': TextStyle(color: Color(0xFFABB2BF), backgroundColor: Colors.transparent),
    'comment': TextStyle(color: Color(0xFF5C6370), fontStyle: FontStyle.italic),
    'keyword': TextStyle(color: Color(0xFFC678DD)),
    'built_in': TextStyle(color: Color(0xFFE5C07B)),
    'type': TextStyle(color: Color(0xFFE5C07B)),
    'literal': TextStyle(color: Color(0xFF56B6C2)),
    'number': TextStyle(color: Color(0xFFD19A66)),
    'regexp': TextStyle(color: Color(0xFF98C379)),
    'string': TextStyle(color: Color(0xFF98C379)),
    'subst': TextStyle(color: Color(0xFFABB2BF)),
    'symbol': TextStyle(color: Color(0xFF61AFEF)),
    'class': TextStyle(color: Color(0xFFE5C07B)),
    'function': TextStyle(color: Color(0xFF61AFEF)),
    'title': TextStyle(color: Color(0xFF61AFEF)),
    'params': TextStyle(color: Color(0xFFABB2BF)),
    'formula': TextStyle(color: Color(0xFF98C379)),
    'comment-doc': TextStyle(color: Color(0xFF5C6370), fontStyle: FontStyle.italic),
    'meta': TextStyle(color: Color(0xFF56B6C2)),
    'tag': TextStyle(color: Color(0xFFE06C75)),
    'name': TextStyle(color: Color(0xFFE06C75)),
    'attr': TextStyle(color: Color(0xFFD19A66)),
    'attribute': TextStyle(color: Color(0xFFD19A66)),
    'variable': TextStyle(color: Color(0xFFE06C75)),
    'bullet': TextStyle(color: Color(0xFF61AFEF)),
    'code': TextStyle(color: Color(0xFF98C379)),
    'emphasis': TextStyle(fontStyle: FontStyle.italic),
    'strong': TextStyle(fontWeight: FontWeight.bold),
    'link': TextStyle(color: Color(0xFF56B6C2), decoration: TextDecoration.underline),
    'section': TextStyle(color: Color(0xFFE06C75), fontWeight: FontWeight.bold),
    'selector-tag': TextStyle(color: Color(0xFFE06C75)),
    'selector-id': TextStyle(color: Color(0xFF61AFEF)),
    'selector-class': TextStyle(color: Color(0xFFD19A66)),
    'addition': TextStyle(color: Color(0xFF98C379)),
    'deletion': TextStyle(color: Color(0xFFE06C75)),
  };
}

// ── Diff body ────────────────────────────────────────────────────────────────

class _DiffBody extends StatelessWidget {
  const _DiffBody({required this.tab});
  final EditorTab tab;

  @override
  Widget build(BuildContext context) {
    final hunks = tab.diffHunks!;
    if (hunks.isEmpty) {
      return const Center(
        child: Text('No changes', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: hunks.length,
      itemBuilder: (context, i) => _DiffHunkWidget(hunk: hunks[i]),
    );
  }
}

class _DiffHunkWidget extends StatelessWidget {
  const _DiffHunkWidget({required this.hunk});
  final DiffHunk hunk;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
            child: Text(
              hunk.header,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          ...hunk.lines.where((l) => l.type != DiffLineType.header).map(
                (line) => _DiffLineWidget(line: line),
              ),
        ],
      ),
    );
  }
}

class _DiffLineWidget extends StatelessWidget {
  const _DiffLineWidget({required this.line});
  final DiffLine line;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    String prefix;

    switch (line.type) {
      case DiffLineType.add:
        bg = AppColors.diffAddBg;
        textColor = AppColors.diffAddText;
        prefix = '+';
      case DiffLineType.remove:
        bg = AppColors.diffRemoveBg;
        textColor = AppColors.diffRemoveText;
        prefix = '-';
      default:
        bg = Colors.transparent;
        textColor = AppColors.textSecondary;
        prefix = ' ';
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${line.oldLineNum ?? ""}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '${line.newLineNum ?? ""}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            prefix,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              line.content,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
