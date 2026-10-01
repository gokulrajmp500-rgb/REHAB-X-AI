import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/data/models/app_settings.dart';
import 'package:flutter_application_1/data/repositories/local_rehab_repository.dart';

void main() {
  test('persists and normalizes unit and camera preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalRehabRepository(await SharedPreferences.getInstance());
    await repository.saveSettings(const AppSettings(unitSystem: 'imperial', frontCamera: true));
    final settings = await repository.loadSettings();
    expect(settings.unitSystem, 'imperial');
    expect(settings.frontCamera, isTrue);
  });

  test('invalid settings recover to metric rear-camera defaults', () async {
    SharedPreferences.setMockInitialValues({'app_settings': '{"unitSystem":"unknown","frontCamera":"bad"}'});
    final settings = await LocalRehabRepository(await SharedPreferences.getInstance()).loadSettings();
    expect(settings.unitSystem, 'metric');
    expect(settings.frontCamera, isFalse);
  });
}