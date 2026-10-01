import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/sports_glass_card.dart';
import '../../data/models/research_article.dart';
import '../../data/services/research_service.dart';

class ResearchKnowledgePage extends StatefulWidget {
  const ResearchKnowledgePage({super.key});

  @override
  State<ResearchKnowledgePage> createState() => _ResearchKnowledgePageState();
}

class _ResearchKnowledgePageState extends State<ResearchKnowledgePage> {
  final _service = const ResearchService();
  String _query = '';
  String _selectedCategory = 'All';
  List<ResearchArticle> _articles = [];
  bool _isLoading = true;

  final _categories = [
    'All',
    'Sports Science',
    'Movement Mechanics',
    'Exercise Technique',
    'Warm-Up Concepts',
    'Recovery Education',
    'Return-to-Play Education',
  ];

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    final res = await _service.search(_query, category: _selectedCategory);
    if (mounted) {
      setState(() {
        _articles = res.articles;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports Science Knowledge Base'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Row(
            children: [
              SportsChip(label: 'VETTED RESEARCH LAYER', color: AppColors.cyan, icon: Icons.menu_book),
              Spacer(),
              Text('PEER-REVIEWED CITATIONS', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Explore controlled biomechanics research, recovery protocols, and exercise science with complete scholarly citations.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Search Box
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, color: AppColors.cyan),
              hintText: 'Search movement science, kinematics...',
            ),
            onChanged: (val) {
              _query = val;
              _search();
            },
          ),
          const SizedBox(height: 12),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((c) {
                final isSel = _selectedCategory == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: isSel,
                    onSelected: (_) {
                      setState(() => _selectedCategory = c);
                      _search();
                    },
                    selectedColor: AppColors.cyan.withAlpha(40),
                    labelStyle: TextStyle(
                      color: isSel ? AppColors.cyan : AppColors.text,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_articles.isEmpty)
            const SportsGlassCard(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No research articles found matching your query.'),
              ),
            )
          else
            ..._articles.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ArticleCard(
                    article: a,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ArticleDetailPage(article: a)),
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          const Text(
            'Educational research summary for sports science training. Not intended as medical diagnosis or clearance.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onTap});
  final ResearchArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SportsGlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SportsChip(label: article.category.toUpperCase(), color: AppColors.cyan),
              const Spacer(),
              Text(
                article.citation.publicationDate,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            article.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            article.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.source_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  article.citation.sourceName,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
            ],
          ),
        ],
      ),
    );
  }
}

class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({super.key, required this.article});
  final ResearchArticle article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Research Article'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          SportsChip(label: article.category.toUpperCase(), color: AppColors.cyan),
          const SizedBox(height: 12),
          Text(
            article.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
          ),
          const SizedBox(height: 16),

          // Overview
          SportsGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RESEARCH SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Text(
                  article.summary,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Key Findings
          SportsGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KEY FINDINGS & IMPLICATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 0.8)),
                const SizedBox(height: 10),
                ...article.keyFindings.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(f, style: const TextStyle(fontSize: 13, height: 1.45)),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scholarly Source Citation (Requirement 24)
          SportsGlassCard(
            borderColor: AppColors.line,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 16, color: AppColors.green),
                    SizedBox(width: 6),
                    Text('SOURCE CITATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.green, letterSpacing: 0.8)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Source Journal: ${article.citation.sourceName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Article Title: "${article.citation.articleTitle}"', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text('Organization: ${article.citation.authorOrOrganization}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text('Publication Date: ${article.citation.publicationDate}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 6),
                Text('Reference URL: ${article.citation.url}', style: const TextStyle(fontSize: 11, color: AppColors.cyan)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Scientific publication summary for education only. REHAB-X AI does not offer medical advice.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
