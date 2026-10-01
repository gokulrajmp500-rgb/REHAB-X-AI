import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/data/repositories/local_rehab_repository.dart';

void main() {
  test('corrupted athlete profile is treated as missing data', () async {
    SharedPreferences.setMockInitialValues({'athlete_profile': '{invalid'});
    final profile = await LocalRehabRepository(await SharedPreferences.getInstance()).loadProfile();
    expect(profile, isNull);
  });
}