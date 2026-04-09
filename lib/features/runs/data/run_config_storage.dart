import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/features/runs/models/run_config.dart';

class RunConfigStorage {
  RunConfigStorage._();
  static final instance = RunConfigStorage._();

  String _key(String workspacePath) => 'run_configs_$workspacePath';

  Future<List<RunConfig>> load(String workspacePath) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key(workspacePath));
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => RunConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(String workspacePath, List<RunConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(configs.map((c) => c.toJson()).toList());
    await prefs.setString(_key(workspacePath), json);
  }
}
