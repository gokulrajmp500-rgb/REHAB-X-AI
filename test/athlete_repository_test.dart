import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/data/models/athlete_profile.dart';
import 'package:flutter_application_1/data/repositories/local_rehab_repository.dart';

void main() {
  test('persists and restores an athlete profile locally', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalRehabRepository(await SharedPreferences.getInstance());
    const profile = AthleteProfile(name: 'Maya', sport: 'Football', recoveryStage: 'Stability');
    await repository.saveProfile(profile);

    expect(await repository.loadProfile(), isA<AthleteProfile>().having((value) => value.name, 'name', 'Maya'));
    await repository.clearAll();
    expect(await repository.loadProfile(), isNull);
  });
}