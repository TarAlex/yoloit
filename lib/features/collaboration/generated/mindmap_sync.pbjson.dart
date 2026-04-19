// This is a generated file - do not edit.
//
// Generated from mindmap_sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use vec2Descriptor instead')
const Vec2$json = {
  '1': 'Vec2',
  '2': [
    {'1': 'x', '3': 1, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 2, '4': 1, '5': 2, '10': 'y'},
  ],
};

/// Descriptor for `Vec2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List vec2Descriptor =
    $convert.base64Decode('CgRWZWMyEgwKAXgYASABKAJSAXgSDAoBeRgCIAEoAlIBeQ==');

@$core.Deprecated('Use stateSnapshotDescriptor instead')
const StateSnapshot$json = {
  '1': 'StateSnapshot',
  '2': [
    {
      '1': 'positions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yoloit.mindmap.StateSnapshot.PositionsEntry',
      '10': 'positions'
    },
    {
      '1': 'sizes',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.yoloit.mindmap.StateSnapshot.SizesEntry',
      '10': 'sizes'
    },
    {'1': 'hidden', '3': 3, '4': 3, '5': 9, '10': 'hidden'},
    {'1': 'hidden_types', '3': 4, '4': 3, '5': 9, '10': 'hiddenTypes'},
  ],
  '3': [StateSnapshot_PositionsEntry$json, StateSnapshot_SizesEntry$json],
};

@$core.Deprecated('Use stateSnapshotDescriptor instead')
const StateSnapshot_PositionsEntry$json = {
  '1': 'PositionsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.Vec2',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use stateSnapshotDescriptor instead')
const StateSnapshot_SizesEntry$json = {
  '1': 'SizesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.Vec2',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `StateSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stateSnapshotDescriptor = $convert.base64Decode(
    'Cg1TdGF0ZVNuYXBzaG90EkoKCXBvc2l0aW9ucxgBIAMoCzIsLnlvbG9pdC5taW5kbWFwLlN0YX'
    'RlU25hcHNob3QuUG9zaXRpb25zRW50cnlSCXBvc2l0aW9ucxI+CgVzaXplcxgCIAMoCzIoLnlv'
    'bG9pdC5taW5kbWFwLlN0YXRlU25hcHNob3QuU2l6ZXNFbnRyeVIFc2l6ZXMSFgoGaGlkZGVuGA'
    'MgAygJUgZoaWRkZW4SIQoMaGlkZGVuX3R5cGVzGAQgAygJUgtoaWRkZW5UeXBlcxpSCg5Qb3Np'
    'dGlvbnNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIqCgV2YWx1ZRgCIAEoCzIULnlvbG9pdC5taW'
    '5kbWFwLlZlYzJSBXZhbHVlOgI4ARpOCgpTaXplc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EioK'
    'BXZhbHVlGAIgASgLMhQueW9sb2l0Lm1pbmRtYXAuVmVjMlIFdmFsdWU6AjgB');

@$core.Deprecated('Use nodeMovedDescriptor instead')
const NodeMoved$json = {
  '1': 'NodeMoved',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 9, '10': 'nodeId'},
    {'1': 'x', '3': 2, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 3, '4': 1, '5': 2, '10': 'y'},
  ],
};

/// Descriptor for `NodeMoved`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeMovedDescriptor = $convert.base64Decode(
    'CglOb2RlTW92ZWQSFwoHbm9kZV9pZBgBIAEoCVIGbm9kZUlkEgwKAXgYAiABKAJSAXgSDAoBeR'
    'gDIAEoAlIBeQ==');

@$core.Deprecated('Use nodeResizedDescriptor instead')
const NodeResized$json = {
  '1': 'NodeResized',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 9, '10': 'nodeId'},
    {'1': 'width', '3': 2, '4': 1, '5': 2, '10': 'width'},
    {'1': 'height', '3': 3, '4': 1, '5': 2, '10': 'height'},
  ],
};

/// Descriptor for `NodeResized`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeResizedDescriptor = $convert.base64Decode(
    'CgtOb2RlUmVzaXplZBIXCgdub2RlX2lkGAEgASgJUgZub2RlSWQSFAoFd2lkdGgYAiABKAJSBX'
    'dpZHRoEhYKBmhlaWdodBgDIAEoAlIGaGVpZ2h0');

@$core.Deprecated('Use nodeToggledDescriptor instead')
const NodeToggled$json = {
  '1': 'NodeToggled',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 9, '10': 'nodeId'},
    {'1': 'hidden', '3': 2, '4': 1, '5': 8, '10': 'hidden'},
  ],
};

/// Descriptor for `NodeToggled`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeToggledDescriptor = $convert.base64Decode(
    'CgtOb2RlVG9nZ2xlZBIXCgdub2RlX2lkGAEgASgJUgZub2RlSWQSFgoGaGlkZGVuGAIgASgIUg'
    'ZoaWRkZW4=');

@$core.Deprecated('Use deltaEventDescriptor instead')
const DeltaEvent$json = {
  '1': 'DeltaEvent',
  '2': [
    {
      '1': 'moved',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.NodeMoved',
      '9': 0,
      '10': 'moved'
    },
    {
      '1': 'resized',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.NodeResized',
      '9': 0,
      '10': 'resized'
    },
    {
      '1': 'toggled',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.NodeToggled',
      '9': 0,
      '10': 'toggled'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `DeltaEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deltaEventDescriptor = $convert.base64Decode(
    'CgpEZWx0YUV2ZW50EjEKBW1vdmVkGAEgASgLMhkueW9sb2l0Lm1pbmRtYXAuTm9kZU1vdmVkSA'
    'BSBW1vdmVkEjcKB3Jlc2l6ZWQYAiABKAsyGy55b2xvaXQubWluZG1hcC5Ob2RlUmVzaXplZEgA'
    'UgdyZXNpemVkEjcKB3RvZ2dsZWQYAyABKAsyGy55b2xvaXQubWluZG1hcC5Ob2RlVG9nZ2xlZE'
    'gAUgd0b2dnbGVkQgYKBGtpbmQ=');

@$core.Deprecated('Use clientHelloDescriptor instead')
const ClientHello$json = {
  '1': 'ClientHello',
  '2': [
    {'1': 'client_id', '3': 1, '4': 1, '5': 9, '10': 'clientId'},
    {'1': 'client_name', '3': 2, '4': 1, '5': 9, '10': 'clientName'},
    {'1': 'version', '3': 3, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `ClientHello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientHelloDescriptor = $convert.base64Decode(
    'CgtDbGllbnRIZWxsbxIbCgljbGllbnRfaWQYASABKAlSCGNsaWVudElkEh8KC2NsaWVudF9uYW'
    '1lGAIgASgJUgpjbGllbnROYW1lEhgKB3ZlcnNpb24YAyABKAlSB3ZlcnNpb24=');

@$core.Deprecated('Use clientConnectedDescriptor instead')
const ClientConnected$json = {
  '1': 'ClientConnected',
  '2': [
    {'1': 'client_id', '3': 1, '4': 1, '5': 9, '10': 'clientId'},
    {'1': 'client_name', '3': 2, '4': 1, '5': 9, '10': 'clientName'},
  ],
};

/// Descriptor for `ClientConnected`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientConnectedDescriptor = $convert.base64Decode(
    'Cg9DbGllbnRDb25uZWN0ZWQSGwoJY2xpZW50X2lkGAEgASgJUghjbGllbnRJZBIfCgtjbGllbn'
    'RfbmFtZRgCIAEoCVIKY2xpZW50TmFtZQ==');

@$core.Deprecated('Use clientDisconnectedDescriptor instead')
const ClientDisconnected$json = {
  '1': 'ClientDisconnected',
  '2': [
    {'1': 'client_id', '3': 1, '4': 1, '5': 9, '10': 'clientId'},
  ],
};

/// Descriptor for `ClientDisconnected`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientDisconnectedDescriptor =
    $convert.base64Decode(
        'ChJDbGllbnREaXNjb25uZWN0ZWQSGwoJY2xpZW50X2lkGAEgASgJUghjbGllbnRJZA==');

@$core.Deprecated('Use syncEnvelopeDescriptor instead')
const SyncEnvelope$json = {
  '1': 'SyncEnvelope',
  '2': [
    {'1': 'sender_id', '3': 1, '4': 1, '5': 9, '10': 'senderId'},
    {
      '1': 'snapshot',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.StateSnapshot',
      '9': 0,
      '10': 'snapshot'
    },
    {
      '1': 'delta',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.DeltaEvent',
      '9': 0,
      '10': 'delta'
    },
    {
      '1': 'hello',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.ClientHello',
      '9': 0,
      '10': 'hello'
    },
    {
      '1': 'connected',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.ClientConnected',
      '9': 0,
      '10': 'connected'
    },
    {
      '1': 'disconnected',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.yoloit.mindmap.ClientDisconnected',
      '9': 0,
      '10': 'disconnected'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `SyncEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncEnvelopeDescriptor = $convert.base64Decode(
    'CgxTeW5jRW52ZWxvcGUSGwoJc2VuZGVyX2lkGAEgASgJUghzZW5kZXJJZBI7CghzbmFwc2hvdB'
    'gCIAEoCzIdLnlvbG9pdC5taW5kbWFwLlN0YXRlU25hcHNob3RIAFIIc25hcHNob3QSMgoFZGVs'
    'dGEYAyABKAsyGi55b2xvaXQubWluZG1hcC5EZWx0YUV2ZW50SABSBWRlbHRhEjMKBWhlbGxvGA'
    'QgASgLMhsueW9sb2l0Lm1pbmRtYXAuQ2xpZW50SGVsbG9IAFIFaGVsbG8SPwoJY29ubmVjdGVk'
    'GAUgASgLMh8ueW9sb2l0Lm1pbmRtYXAuQ2xpZW50Q29ubmVjdGVkSABSCWNvbm5lY3RlZBJICg'
    'xkaXNjb25uZWN0ZWQYBiABKAsyIi55b2xvaXQubWluZG1hcC5DbGllbnREaXNjb25uZWN0ZWRI'
    'AFIMZGlzY29ubmVjdGVkQgkKB3BheWxvYWQ=');
