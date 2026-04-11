enum PanelVisibility { open, collapsed, closed }

extension PanelVisibilityX on PanelVisibility {
  String toPrefsString() => name;
}

PanelVisibility panelVisibilityFromPrefs(String? s) =>
    PanelVisibility.values.firstWhere(
      (v) => v.name == s,
      orElse: () => PanelVisibility.open,
    );
