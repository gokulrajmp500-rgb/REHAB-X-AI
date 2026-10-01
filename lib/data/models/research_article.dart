class ResearchSourceCitation {
  const ResearchSourceCitation({
    required this.sourceName,
    required this.articleTitle,
    required this.url,
    this.publicationDate = '2024',
    this.authorOrOrganization = '',
  });

  final String sourceName;
  final String articleTitle;
  final String url;
  final String publicationDate;
  final String authorOrOrganization;

  Map<String, String> toJson() => {
    'sourceName': sourceName,
    'articleTitle': articleTitle,
    'url': url,
    'publicationDate': publicationDate,
    'authorOrOrganization': authorOrOrganization,
  };

  factory ResearchSourceCitation.fromJson(Map<String, Object?> json) => ResearchSourceCitation(
    sourceName: json['sourceName']?.toString() ?? '',
    articleTitle: json['articleTitle']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    publicationDate: json['publicationDate']?.toString() ?? '',
    authorOrOrganization: json['authorOrOrganization']?.toString() ?? '',
  );
}

class ResearchArticle {
  const ResearchArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.keyFindings,
    required this.citation,
    this.isBookmarked = false,
  });

  final String id;
  final String title;
  final String category;
  final String summary;
  final List<String> keyFindings;
  final ResearchSourceCitation citation;
  final bool isBookmarked;

  ResearchArticle copyWith({bool? isBookmarked}) => ResearchArticle(
    id: id,
    title: title,
    category: category,
    summary: summary,
    keyFindings: keyFindings,
    citation: citation,
    isBookmarked: isBookmarked ?? this.isBookmarked,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'summary': summary,
    'keyFindings': keyFindings,
    'citation': citation.toJson(),
    'isBookmarked': isBookmarked,
  };

  factory ResearchArticle.fromJson(Map<String, Object?> json) => ResearchArticle(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? 'Sports Science',
    summary: json['summary'] as String? ?? '',
    keyFindings: List<String>.from(json['keyFindings'] as List? ?? const []),
    citation: ResearchSourceCitation.fromJson(Map<String, Object?>.from(json['citation'] as Map? ?? {})),
    isBookmarked: json['isBookmarked'] as bool? ?? false,
  );
}
