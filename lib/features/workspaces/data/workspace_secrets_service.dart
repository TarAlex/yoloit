import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WorkspaceSecretsService {
  WorkspaceSecretsService._();
  static final WorkspaceSecretsService instance = WorkspaceSecretsService._();

  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(accountName: 'yoloit'),
  );

  String _key(String workspaceId) => 'ws_secrets_$workspaceId';

  Future<Map<String, String>> load(String workspaceId) async {
    final raw = await _storage.read(key: _key(workspaceId));
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> save(String workspaceId, Map<String, String> secrets) async {
    await _storage.write(key: _key(workspaceId), value: jsonEncode(secrets));
  }

  Future<void> delete(String workspaceId) async {
    await _storage.delete(key: _key(workspaceId));
  }
}
