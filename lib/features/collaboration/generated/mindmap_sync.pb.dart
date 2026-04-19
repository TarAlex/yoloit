// This is a generated file - do not edit.
//
// Generated from mindmap_sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Vec2 extends $pb.GeneratedMessage {
  factory Vec2({
    $core.double? x,
    $core.double? y,
  }) {
    final result = create();
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    return result;
  }

  Vec2._();

  factory Vec2.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Vec2.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Vec2',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..a<double>(1, _omitFieldNames ? '' : 'x', $pb.PbFieldType.OF)
    ..a<double>(2, _omitFieldNames ? '' : 'y', $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Vec2 clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Vec2 copyWith(void Function(Vec2) updates) =>
      super.copyWith((message) => updates(message as Vec2)) as Vec2;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Vec2 create() => Vec2._();
  @$core.override
  Vec2 createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Vec2 getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Vec2>(create);
  static Vec2? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get x => $_getN(0);
  @$pb.TagNumber(1)
  set x($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasX() => $_has(0);
  @$pb.TagNumber(1)
  void clearX() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get y => $_getN(1);
  @$pb.TagNumber(2)
  set y($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasY() => $_has(1);
  @$pb.TagNumber(2)
  void clearY() => clearField(2);
}

class StateSnapshot extends $pb.GeneratedMessage {
  factory StateSnapshot({
    $core.Iterable<$core.MapEntry<$core.String, Vec2>>? positions,
    $core.Iterable<$core.MapEntry<$core.String, Vec2>>? sizes,
    $core.Iterable<$core.String>? hidden,
    $core.Iterable<$core.String>? hiddenTypes,
  }) {
    final result = create();
    if (positions != null) result.positions.addEntries(positions);
    if (sizes != null) result.sizes.addEntries(sizes);
    if (hidden != null) result.hidden.addAll(hidden);
    if (hiddenTypes != null) result.hiddenTypes.addAll(hiddenTypes);
    return result;
  }

  StateSnapshot._();

  factory StateSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StateSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StateSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..m<$core.String, Vec2>(1, _omitFieldNames ? '' : 'positions',
        entryClassName: 'StateSnapshot.PositionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Vec2.create,
        valueDefaultOrMaker: Vec2.getDefault,
        packageName: const $pb.PackageName('yoloit.mindmap'))
    ..m<$core.String, Vec2>(2, _omitFieldNames ? '' : 'sizes',
        entryClassName: 'StateSnapshot.SizesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Vec2.create,
        valueDefaultOrMaker: Vec2.getDefault,
        packageName: const $pb.PackageName('yoloit.mindmap'))
    ..pPS(3, _omitFieldNames ? '' : 'hidden')
    ..pPS(4, _omitFieldNames ? '' : 'hiddenTypes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StateSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StateSnapshot copyWith(void Function(StateSnapshot) updates) =>
      super.copyWith((message) => updates(message as StateSnapshot))
          as StateSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StateSnapshot create() => StateSnapshot._();
  @$core.override
  StateSnapshot createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StateSnapshot getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StateSnapshot>(create);
  static StateSnapshot? _defaultInstance;

  @$pb.TagNumber(1)
  Map<$core.String, Vec2> get positions => $_getMap(0);

  @$pb.TagNumber(2)
  Map<$core.String, Vec2> get sizes => $_getMap(1);

  @$pb.TagNumber(3)
  List<$core.String> get hidden => $_getList(2);

  @$pb.TagNumber(4)
  List<$core.String> get hiddenTypes => $_getList(3);
}

class NodeMoved extends $pb.GeneratedMessage {
  factory NodeMoved({
    $core.String? nodeId,
    $core.double? x,
    $core.double? y,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    return result;
  }

  NodeMoved._();

  factory NodeMoved.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeMoved.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeMoved',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nodeId')
    ..a<double>(2, _omitFieldNames ? '' : 'x', $pb.PbFieldType.OF)
    ..a<double>(3, _omitFieldNames ? '' : 'y', $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeMoved clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeMoved copyWith(void Function(NodeMoved) updates) =>
      super.copyWith((message) => updates(message as NodeMoved)) as NodeMoved;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeMoved create() => NodeMoved._();
  @$core.override
  NodeMoved createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeMoved getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeMoved>(create);
  static NodeMoved? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nodeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set nodeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get x => $_getN(1);
  @$pb.TagNumber(2)
  set x($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasX() => $_has(1);
  @$pb.TagNumber(2)
  void clearX() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get y => $_getN(2);
  @$pb.TagNumber(3)
  set y($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasY() => $_has(2);
  @$pb.TagNumber(3)
  void clearY() => clearField(3);
}

class NodeResized extends $pb.GeneratedMessage {
  factory NodeResized({
    $core.String? nodeId,
    $core.double? width,
    $core.double? height,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  NodeResized._();

  factory NodeResized.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeResized.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeResized',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nodeId')
    ..a<double>(2, _omitFieldNames ? '' : 'width', $pb.PbFieldType.OF)
    ..a<double>(3, _omitFieldNames ? '' : 'height', $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeResized clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeResized copyWith(void Function(NodeResized) updates) =>
      super.copyWith((message) => updates(message as NodeResized))
          as NodeResized;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeResized create() => NodeResized._();
  @$core.override
  NodeResized createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeResized getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeResized>(create);
  static NodeResized? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nodeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set nodeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get width => $_getN(1);
  @$pb.TagNumber(2)
  set width($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get height => $_getN(2);
  @$pb.TagNumber(3)
  set height($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeight() => clearField(3);
}

class NodeToggled extends $pb.GeneratedMessage {
  factory NodeToggled({
    $core.String? nodeId,
    $core.bool? hidden,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (hidden != null) result.hidden = hidden;
    return result;
  }

  NodeToggled._();

  factory NodeToggled.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeToggled.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeToggled',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nodeId')
    ..aOB(2, _omitFieldNames ? '' : 'hidden')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeToggled clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeToggled copyWith(void Function(NodeToggled) updates) =>
      super.copyWith((message) => updates(message as NodeToggled))
          as NodeToggled;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeToggled create() => NodeToggled._();
  @$core.override
  NodeToggled createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeToggled getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeToggled>(create);
  static NodeToggled? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nodeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set nodeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get hidden => $_getBF(1);
  @$pb.TagNumber(2)
  set hidden($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHidden() => $_has(1);
  @$pb.TagNumber(2)
  void clearHidden() => clearField(2);
}

enum DeltaEvent_Kind { moved, resized, toggled, notSet }

class DeltaEvent extends $pb.GeneratedMessage {
  factory DeltaEvent({
    NodeMoved? moved,
    NodeResized? resized,
    NodeToggled? toggled,
  }) {
    final result = create();
    if (moved != null) result.moved = moved;
    if (resized != null) result.resized = resized;
    if (toggled != null) result.toggled = toggled;
    return result;
  }

  DeltaEvent._();

  factory DeltaEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeltaEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, DeltaEvent_Kind> _DeltaEvent_KindByTag = {
    1: DeltaEvent_Kind.moved,
    2: DeltaEvent_Kind.resized,
    3: DeltaEvent_Kind.toggled,
    0: DeltaEvent_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeltaEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..aOM<NodeMoved>(1, _omitFieldNames ? '' : 'moved',
        subBuilder: NodeMoved.create)
    ..aOM<NodeResized>(2, _omitFieldNames ? '' : 'resized',
        subBuilder: NodeResized.create)
    ..aOM<NodeToggled>(3, _omitFieldNames ? '' : 'toggled',
        subBuilder: NodeToggled.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeltaEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeltaEvent copyWith(void Function(DeltaEvent) updates) =>
      super.copyWith((message) => updates(message as DeltaEvent)) as DeltaEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeltaEvent create() => DeltaEvent._();
  @$core.override
  DeltaEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeltaEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeltaEvent>(create);
  static DeltaEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  DeltaEvent_Kind whichKind() => _DeltaEvent_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearKind() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  NodeMoved get moved => $_getN(0);
  @$pb.TagNumber(1)
  set moved(NodeMoved value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMoved() => $_has(0);
  @$pb.TagNumber(1)
  void clearMoved() => clearField(1);
  @$pb.TagNumber(1)
  NodeMoved ensureMoved() => $_ensure(0);

  @$pb.TagNumber(2)
  NodeResized get resized => $_getN(1);
  @$pb.TagNumber(2)
  set resized(NodeResized value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResized() => $_has(1);
  @$pb.TagNumber(2)
  void clearResized() => clearField(2);
  @$pb.TagNumber(2)
  NodeResized ensureResized() => $_ensure(1);

  @$pb.TagNumber(3)
  NodeToggled get toggled => $_getN(2);
  @$pb.TagNumber(3)
  set toggled(NodeToggled value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasToggled() => $_has(2);
  @$pb.TagNumber(3)
  void clearToggled() => clearField(3);
  @$pb.TagNumber(3)
  NodeToggled ensureToggled() => $_ensure(2);
}

class ClientHello extends $pb.GeneratedMessage {
  factory ClientHello({
    $core.String? clientId,
    $core.String? clientName,
    $core.String? version,
  }) {
    final result = create();
    if (clientId != null) result.clientId = clientId;
    if (clientName != null) result.clientName = clientName;
    if (version != null) result.version = version;
    return result;
  }

  ClientHello._();

  factory ClientHello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientHello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientHello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'clientId')
    ..aOS(2, _omitFieldNames ? '' : 'clientName')
    ..aOS(3, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientHello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientHello copyWith(void Function(ClientHello) updates) =>
      super.copyWith((message) => updates(message as ClientHello))
          as ClientHello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientHello create() => ClientHello._();
  @$core.override
  ClientHello createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientHello getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientHello>(create);
  static ClientHello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get clientId => $_getSZ(0);
  @$pb.TagNumber(1)
  set clientId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClientId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get clientName => $_getSZ(1);
  @$pb.TagNumber(2)
  set clientName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClientName() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientName() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get version => $_getSZ(2);
  @$pb.TagNumber(3)
  set version($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearVersion() => clearField(3);
}

class ClientConnected extends $pb.GeneratedMessage {
  factory ClientConnected({
    $core.String? clientId,
    $core.String? clientName,
  }) {
    final result = create();
    if (clientId != null) result.clientId = clientId;
    if (clientName != null) result.clientName = clientName;
    return result;
  }

  ClientConnected._();

  factory ClientConnected.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientConnected.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientConnected',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'clientId')
    ..aOS(2, _omitFieldNames ? '' : 'clientName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientConnected clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientConnected copyWith(void Function(ClientConnected) updates) =>
      super.copyWith((message) => updates(message as ClientConnected))
          as ClientConnected;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientConnected create() => ClientConnected._();
  @$core.override
  ClientConnected createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientConnected getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientConnected>(create);
  static ClientConnected? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get clientId => $_getSZ(0);
  @$pb.TagNumber(1)
  set clientId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClientId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get clientName => $_getSZ(1);
  @$pb.TagNumber(2)
  set clientName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClientName() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientName() => clearField(2);
}

class ClientDisconnected extends $pb.GeneratedMessage {
  factory ClientDisconnected({
    $core.String? clientId,
  }) {
    final result = create();
    if (clientId != null) result.clientId = clientId;
    return result;
  }

  ClientDisconnected._();

  factory ClientDisconnected.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientDisconnected.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientDisconnected',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'clientId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientDisconnected clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientDisconnected copyWith(void Function(ClientDisconnected) updates) =>
      super.copyWith((message) => updates(message as ClientDisconnected))
          as ClientDisconnected;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientDisconnected create() => ClientDisconnected._();
  @$core.override
  ClientDisconnected createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientDisconnected getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientDisconnected>(create);
  static ClientDisconnected? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get clientId => $_getSZ(0);
  @$pb.TagNumber(1)
  set clientId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClientId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientId() => clearField(1);
}

enum SyncEnvelope_Payload {
  snapshot,
  delta,
  hello,
  connected,
  disconnected,
  notSet
}

class SyncEnvelope extends $pb.GeneratedMessage {
  factory SyncEnvelope({
    $core.String? senderId,
    StateSnapshot? snapshot,
    DeltaEvent? delta,
    ClientHello? hello,
    ClientConnected? connected,
    ClientDisconnected? disconnected,
  }) {
    final result = create();
    if (senderId != null) result.senderId = senderId;
    if (snapshot != null) result.snapshot = snapshot;
    if (delta != null) result.delta = delta;
    if (hello != null) result.hello = hello;
    if (connected != null) result.connected = connected;
    if (disconnected != null) result.disconnected = disconnected;
    return result;
  }

  SyncEnvelope._();

  factory SyncEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SyncEnvelope_Payload>
      _SyncEnvelope_PayloadByTag = {
    2: SyncEnvelope_Payload.snapshot,
    3: SyncEnvelope_Payload.delta,
    4: SyncEnvelope_Payload.hello,
    5: SyncEnvelope_Payload.connected,
    6: SyncEnvelope_Payload.disconnected,
    0: SyncEnvelope_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncEnvelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yoloit.mindmap'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6])
    ..aOS(1, _omitFieldNames ? '' : 'senderId')
    ..aOM<StateSnapshot>(2, _omitFieldNames ? '' : 'snapshot',
        subBuilder: StateSnapshot.create)
    ..aOM<DeltaEvent>(3, _omitFieldNames ? '' : 'delta',
        subBuilder: DeltaEvent.create)
    ..aOM<ClientHello>(4, _omitFieldNames ? '' : 'hello',
        subBuilder: ClientHello.create)
    ..aOM<ClientConnected>(5, _omitFieldNames ? '' : 'connected',
        subBuilder: ClientConnected.create)
    ..aOM<ClientDisconnected>(6, _omitFieldNames ? '' : 'disconnected',
        subBuilder: ClientDisconnected.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncEnvelope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncEnvelope copyWith(void Function(SyncEnvelope) updates) =>
      super.copyWith((message) => updates(message as SyncEnvelope))
          as SyncEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncEnvelope create() => SyncEnvelope._();
  @$core.override
  SyncEnvelope createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncEnvelope>(create);
  static SyncEnvelope? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  SyncEnvelope_Payload whichPayload() =>
      _SyncEnvelope_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearPayload() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get senderId => $_getSZ(0);
  @$pb.TagNumber(1)
  set senderId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSenderId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSenderId() => clearField(1);

  @$pb.TagNumber(2)
  StateSnapshot get snapshot => $_getN(1);
  @$pb.TagNumber(2)
  set snapshot(StateSnapshot value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSnapshot() => $_has(1);
  @$pb.TagNumber(2)
  void clearSnapshot() => clearField(2);
  @$pb.TagNumber(2)
  StateSnapshot ensureSnapshot() => $_ensure(1);

  @$pb.TagNumber(3)
  DeltaEvent get delta => $_getN(2);
  @$pb.TagNumber(3)
  set delta(DeltaEvent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDelta() => $_has(2);
  @$pb.TagNumber(3)
  void clearDelta() => clearField(3);
  @$pb.TagNumber(3)
  DeltaEvent ensureDelta() => $_ensure(2);

  @$pb.TagNumber(4)
  ClientHello get hello => $_getN(3);
  @$pb.TagNumber(4)
  set hello(ClientHello value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasHello() => $_has(3);
  @$pb.TagNumber(4)
  void clearHello() => clearField(4);
  @$pb.TagNumber(4)
  ClientHello ensureHello() => $_ensure(3);

  @$pb.TagNumber(5)
  ClientConnected get connected => $_getN(4);
  @$pb.TagNumber(5)
  set connected(ClientConnected value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasConnected() => $_has(4);
  @$pb.TagNumber(5)
  void clearConnected() => clearField(5);
  @$pb.TagNumber(5)
  ClientConnected ensureConnected() => $_ensure(4);

  @$pb.TagNumber(6)
  ClientDisconnected get disconnected => $_getN(5);
  @$pb.TagNumber(6)
  set disconnected(ClientDisconnected value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDisconnected() => $_has(5);
  @$pb.TagNumber(6)
  void clearDisconnected() => clearField(6);
  @$pb.TagNumber(6)
  ClientDisconnected ensureDisconnected() => $_ensure(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
