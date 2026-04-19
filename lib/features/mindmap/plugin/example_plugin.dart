// ignore_for_file: unused_element
//
// ════════════════════════════════════════════════════════════════════════════
//  EXAMPLE PLUGIN — "Hello World" mindmap card
//  ─────────────────────────────────────────────────────────────────────────
//  This file is NOT registered at startup — it exists purely as a reference
//  implementation that third-party developers can copy.
//
//  To activate it (for testing):
//    MindMapPluginRegistry.instance.register(HelloWorldPlugin());
//  ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/plugin/mindmap_card_plugin.dart';
import 'package:yoloit/features/mindmap/plugin/mindmap_plugin_registry.dart';

// ── 1. Define your plugin class ────────────────────────────────────────────

class HelloWorldPlugin extends MindMapCardPlugin {
  // ── Identity ──────────────────────────────────────────────────────────────

  @override
  String get pluginId => 'com.example.hello-world';

  @override
  String get displayName => 'Hello World';

  @override
  IconData get icon => Icons.waving_hand_outlined;

  @override
  String get typeTag => 'hello'; // sidebar filter tag

  // ── Card behaviour ────────────────────────────────────────────────────────

  @override
  bool get isResizable => true;

  @override
  Size get minResizeSize => const Size(200, 120);

  // ── Rendering ─────────────────────────────────────────────────────────────

  @override
  Widget buildWidget(MindMapPluginNodeData data) {
    // data.payload contains whatever you put in when creating the node.
    final title = data.payload['title'] as String? ?? 'Hello World';
    final body  = data.payload['body']  as String? ?? 'A plugin card.';
    return _HelloWorldCard(title: title, body: body);
  }

  // ── Data provision ────────────────────────────────────────────────────────

  @override
  List<PluginNodeEntry> provideNodes(BuildContext context) {
    // You can read your own BloCs here via context.read<YourCubit>() if
    // you've provided them higher up in the widget tree.
    //
    // Here we just return one static demo card.
    return [
      PluginNodeEntry(
        data: MindMapPluginNodeData(
          id:          'hello:main',
          pluginId:    pluginId,
          columnIndex: 9,                      // rightmost column
          typeTag:     typeTag,
          defaultSize: const Size(260, 160),
          payload: const {
            'title': 'Hello World',
            'body':  'This card is provided by the HelloWorldPlugin.',
          },
        ),
        // Optional: connect this card from another node.
        // connections: [
        //   MindMapConnection(
        //     fromId: 'hello:main',
        //     toId:   'ws:some-workspace-id',
        //     style:  ConnectorStyle.dashed,
        //     color:  Color(0x60FFAA33),
        //   ),
        // ],
      ),
    ];
  }
}

// ── 2. Define your card widget ─────────────────────────────────────────────
//
// This is just a regular Flutter widget — style it however you like.
// The MindMapNode wrapper (drag handle + resize) is added automatically.

class _HelloWorldCard extends StatelessWidget {
  const _HelloWorldCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        border: Border.all(color: const Color(0x70FFAA33), width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFF121520),
                border: Border(bottom: BorderSide(color: Color(0xFF2A3040))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.waving_hand_outlined, size: 12, color: Color(0xFFFFAA33)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8E8FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  body,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9BAACB), height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 3. Registration (do this in main.dart or a plugin initialiser) ─────────
//
// void main() {
//   MindMapPluginRegistry.instance.register(HelloWorldPlugin());
//   runApp(const MyApp());
// }

// ── HOW A THIRD-PARTY PACKAGE WOULD DO IT ─────────────────────────────────
//
// A standalone Dart package `my_mindmap_plugin` would export:
//   - Its plugin class (implements MindMapCardPlugin)
//   - A top-level `void registerMyPlugin()` helper
//
// The host app adds the package to pubspec.yaml and calls:
//   registerMyPlugin();   // in main() before runApp
//
// No changes to the yoloit source code are needed.
//
// ── PLUGIN SDK SURFACE ─────────────────────────────────────────────────────
//
// Everything a plugin needs is exported from the mindmap feature:
//
//   package:yoloit/features/mindmap/plugin/mindmap_card_plugin.dart
//     └─ MindMapCardPlugin   (abstract class to implement)
//     └─ PluginNodeEntry     (returned by provideNodes)
//
//   package:yoloit/features/mindmap/plugin/mindmap_plugin_registry.dart
//     └─ MindMapPluginRegistry.instance.register(plugin)
//
//   package:yoloit/features/mindmap/model/mindmap_node_model.dart
//     └─ MindMapPluginNodeData   (the node data class to instantiate)
//     └─ MindMapConnection       (connection between two cards)
//     └─ ConnectorStyle          (solid / dashed / animated)
