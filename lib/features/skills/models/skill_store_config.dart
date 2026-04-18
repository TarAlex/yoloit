import 'package:equatable/equatable.dart';
import 'package:yoloit/features/skills/models/skill_entry.dart';

/// Type of skills store.
enum SkillStoreType {
  github,
  url,
  installScript,
  local,
}

/// Configuration for a single skills store source.
class SkillStore extends Equatable {
  const SkillStore({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final SkillStoreType type;

  /// For github: "owner/repo". For url: full URL. For installScript: the shell command.
  final String url;

  /// Built-in stores cannot be removed.
  final bool isBuiltIn;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'url': url,
        'isBuiltIn': isBuiltIn,
      };

  factory SkillStore.fromJson(Map<String, dynamic> j) => SkillStore(
        id: j['id'] as String,
        name: j['name'] as String,
        type: SkillStoreType.values.firstWhere(
          (e) => e.name == (j['type'] as String? ?? 'github'),
          orElse: () => SkillStoreType.github,
        ),
        url: j['url'] as String,
        isBuiltIn: j['isBuiltIn'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, type, url];
}

/// Root config — fetched from GitHub and cached locally.
/// Also contains a [catalog] of known skills so the UI can show them
/// without having to query each store individually.
class SkillsStoreConfig extends Equatable {
  const SkillsStoreConfig({
    required this.stores,
    this.catalog = const [],
  });

  final List<SkillStore> stores;

  /// Pre-defined skill catalog loaded from the remote config.
  final List<SkillEntry> catalog;

  static const List<SkillStore> _builtInStores = [
    SkillStore(
      id: 'flutter-skills',
      name: 'Flutter Skills',
      type: SkillStoreType.github,
      url: 'flutter/skills',
      isBuiltIn: true,
    ),
    SkillStore(
      id: 'remotion-skills',
      name: 'Remotion AI Skills',
      type: SkillStoreType.url,
      url: 'https://www.remotion.dev/docs/ai/skills',
      isBuiltIn: true,
    ),
    SkillStore(
      id: 'dmtools-skills',
      name: 'DMTools Skills',
      type: SkillStoreType.installScript,
      url: 'curl -fsSL https://github.com/epam/dm.ai/releases/download/v1.7.175/skill-install.sh | bash',
      isBuiltIn: true,
    ),
  ];

  static SkillsStoreConfig get defaults =>
      const SkillsStoreConfig(stores: _builtInStores);

  Map<String, dynamic> toJson() => {
        'version': 1,
        'stores': stores.map((s) => s.toJson()).toList(),
        'catalog': catalog.map((e) => e.toJson()).toList(),
      };

  factory SkillsStoreConfig.fromJson(Map<String, dynamic> j) {
    final storeList = (j['stores'] as List? ?? [])
        .map((e) => SkillStore.fromJson(e as Map<String, dynamic>))
        .toList();
    // Merge: ensure all built-in stores are present
    final existingIds = storeList.map((s) => s.id).toSet();
    for (final b in _builtInStores) {
      if (!existingIds.contains(b.id)) storeList.insert(0, b);
    }
    final catalogList = (j['catalog'] as List? ?? [])
        .map((e) => SkillEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return SkillsStoreConfig(stores: storeList, catalog: catalogList);
  }

  SkillsStoreConfig withStore(SkillStore store) =>
      SkillsStoreConfig(stores: [...stores, store], catalog: catalog);

  SkillsStoreConfig withoutStore(String storeId) => SkillsStoreConfig(
        stores: stores.where((s) => s.id != storeId).toList(),
        catalog: catalog,
      );

  @override
  List<Object?> get props => [stores, catalog];
}
