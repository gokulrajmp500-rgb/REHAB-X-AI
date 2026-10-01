class AppSettings {
  const AppSettings({
    this.unitSystem = 'metric',
    this.frontCamera = false,
    this.themeMode = 'dark',
    this.notificationsEnabled = true,
  });

  final String unitSystem;
  final bool frontCamera;
  final String themeMode; // 'dark' | 'light' | 'system'
  final bool notificationsEnabled;

  Map<String, Object?> toJson() => {
        'unitSystem': unitSystem,
        'frontCamera': frontCamera,
        'themeMode': themeMode,
        'notificationsEnabled': notificationsEnabled,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        unitSystem: json['unitSystem'] == 'imperial' ? 'imperial' : 'metric',
        frontCamera: json['frontCamera'] as bool? ?? false,
        themeMode: json['themeMode'] as String? ?? 'dark',
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      );
}