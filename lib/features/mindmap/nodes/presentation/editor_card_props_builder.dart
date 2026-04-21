import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';

EditorCardProps buildEditorCardProps({
  required EditorNodeData data,
  dynamic editorState,
}) {
  final tabs = _readTabs(editorState);
  final activeIndex = _readActiveIndex(editorState, tabs.length);
  final activeTab = tabs.isEmpty ? null : tabs[activeIndex];
  final activePath = _readTabString(activeTab, 'filePath');
  final activeContent = _readTabString(activeTab, 'content');

  return EditorCardProps(
    filePath: activeTab == null
        ? data.filePath
        : (activePath.isNotEmpty ? activePath : data.filePath),
    language: data.language,
    content: activeTab == null ? data.content : activeContent,
    tabs: [
      for (var i = 0; i < tabs.length; i++)
        TabInfo(
          path: _readTabString(tabs[i], 'filePath'),
          isActive: i == activeIndex,
        ),
    ],
  );
}

List<dynamic> _readTabs(dynamic state) {
  if (state == null) return const [];
  try {
    final tabs = state.tabs;
    return tabs is List ? tabs.cast<dynamic>() : const [];
  } catch (_) {
    return const [];
  }
}

int _readActiveIndex(dynamic state, int tabCount) {
  if (state == null || tabCount == 0) return 0;
  try {
    final value = state.activeIndex;
    if (value is int) {
      return value.clamp(0, tabCount - 1);
    }
  } catch (_) {
    // fall through to default
  }
  return 0;
}

String _readTabString(dynamic tab, String field) {
  if (tab == null) return '';
  if (tab is Map<String, dynamic>) {
    return tab[field] as String? ?? '';
  }
  try {
    return switch (field) {
      'filePath' => tab.filePath as String? ?? '',
      'content' => tab.content as String? ?? '',
      _ => '',
    };
  } catch (_) {
    return '';
  }
}
