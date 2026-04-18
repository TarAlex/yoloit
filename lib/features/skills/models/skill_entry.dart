import 'package:equatable/equatable.dart';

/// Where a skill comes from.
enum SkillSourceType {
  github,
  url,
  installScript,
  local,
}

/// A single skill available in the store or installed globally.
class SkillEntry extends Equatable {
  const SkillEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    required this.sourceType,
    this.storeId,
    this.installCommand,
    this.installUrl,
    this.isInstalled = false,
    this.computedHash,
  });

  final String id;
  final String name;
  final String description;
  final String source;
  final SkillSourceType sourceType;

  /// Which store this skill came from (null = global/unknown).
  final String? storeId;

  /// Shell command to install this skill (for installScript type).
  final String? installCommand;

  /// URL for more info or docs.
  final String? installUrl;

  /// Whether the skill is installed in the global skills dir.
  final bool isInstalled;

  /// Hash from skills-lock.json (if available).
  final String? computedHash;

  SkillEntry copyWith({
    bool? isInstalled,
    String? computedHash,
    String? description,
  }) =>
      SkillEntry(
        id: id,
        name: name,
        description: description ?? this.description,
        source: source,
        sourceType: sourceType,
        storeId: storeId,
        installCommand: installCommand,
        installUrl: installUrl,
        isInstalled: isInstalled ?? this.isInstalled,
        computedHash: computedHash ?? this.computedHash,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'source': source,
        'sourceType': sourceType.name,
        'storeId': storeId,
        'installCommand': installCommand,
        'installUrl': installUrl,
        'isInstalled': isInstalled,
        'computedHash': computedHash,
      };

  factory SkillEntry.fromJson(Map<String, dynamic> j) => SkillEntry(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'] as String,
        description: j['description'] as String? ?? '',
        source: j['source'] as String? ?? '',
        sourceType: SkillSourceType.values.firstWhere(
          (e) => e.name == j['sourceType'],
          orElse: () => SkillSourceType.github,
        ),
        storeId: j['storeId'] as String?,
        installCommand: j['installCommand'] as String?,
        installUrl: j['installUrl'] as String?,
        isInstalled: j['isInstalled'] as bool? ?? false,
        computedHash: j['computedHash'] as String?,
      );

  @override
  List<Object?> get props => [id, source, sourceType, isInstalled];
}
