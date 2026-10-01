import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/data/models/competition.dart';
import 'package:flutter_application_1/data/repositories/local_rehab_repository.dart';

void main() {
  group('Competition & Checklist Persistence', () {
    test('persists and loads competition event details', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalRehabRepository(await SharedPreferences.getInstance());

      final comp = CompetitionEvent(
        name: 'National Invitational',
        sport: 'Football',
        event: 'Quarterfinals',
        date: DateTime(2026, 11, 20),
        venue: 'Metro Arena',
      );
      await repo.saveCompetition(comp);

      final loaded = await repo.loadCompetition();
      expect(loaded, isNotNull);
      expect(loaded!.name, 'National Invitational');
      expect(loaded.sport, 'Football');
      expect(loaded.venue, 'Metro Arena');
    });

    test('updates and persists pre-competition checklist items', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalRehabRepository(await SharedPreferences.getInstance());

      final initial = await repo.loadCompetitionChecklist();
      expect(initial, isNotEmpty);

      final updated = initial.map((item) {
        return item.id == 'sleep' ? item.copyWith(completed: true) : item;
      }).toList();

      await repo.saveCompetitionChecklist(updated);
      final reloaded = await repo.loadCompetitionChecklist();
      expect(reloaded.firstWhere((i) => i.id == 'sleep').completed, isTrue);
    });

    test('toggles and persists user favorites', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalRehabRepository(await SharedPreferences.getInstance());

      await repo.toggleFavorite('calf_raise');
      final favs = await repo.loadFavorites();
      expect(favs.contains('calf_raise'), isTrue);

      await repo.toggleFavorite('calf_raise');
      final favs2 = await repo.loadFavorites();
      expect(favs2.contains('calf_raise'), isFalse);
    });
  });
}
