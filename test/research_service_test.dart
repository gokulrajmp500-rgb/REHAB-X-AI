import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/services/research_service.dart';

void main() {
  group('ResearchService', () {
    const service = ResearchService();

    test('curated knowledge base contains vetted scientific articles with citations', () {
      expect(ResearchService.curatedKnowledgeBase, isNotEmpty);
      for (final article in ResearchService.curatedKnowledgeBase) {
        expect(article.title, isNotEmpty);
        expect(article.citation.sourceName, isNotEmpty);
        expect(article.citation.url, isNotEmpty);
        expect(article.keyFindings, isNotEmpty);
      }
    });

    test('searches articles by keyword and preserves source citation', () async {
      final searchResult = await service.search('squat');
      expect(searchResult.articles, isNotEmpty);
      final first = searchResult.articles.first;
      expect(first.title.toLowerCase(), contains('squat'));
      expect(first.citation.sourceName, isNotEmpty);
    });

    test('filters articles by category', () async {
      final searchResult = await service.search('', category: 'Recovery Education');
      expect(searchResult.articles, isNotEmpty);
      for (final a in searchResult.articles) {
        expect(a.category, 'Recovery Education');
      }
    });
  });
}
