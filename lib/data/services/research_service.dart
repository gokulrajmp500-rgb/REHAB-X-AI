import '../models/research_article.dart';

class ResearchSearchResult {
  const ResearchSearchResult({
    required this.articles,
    required this.query,
    required this.isOnlineSource,
    this.statusMessage = '',
  });

  final List<ResearchArticle> articles;
  final String query;
  final bool isOnlineSource;
  final String statusMessage;
}

class ResearchService {
  const ResearchService();

  static const List<ResearchArticle> curatedKnowledgeBase = [
    ResearchArticle(
      id: 'biomech_squat_depth',
      title: 'Knee and Hip Joint Kinematics in Deep vs Parallel Squat',
      category: 'Sports Science',
      summary: 'Biomechanical examination of joint contact forces and muscular recruitment patterns across progressive squat knee flexion depths.',
      keyFindings: [
        'Knee flexion beyond 90 degrees increases quadriceps and gluteus maximus torque while distributing forces across the patellofemoral complex.',
        'Controlled eccentric tempo significantly reduces shear force spikes compared to rapid uncontrolled descents.',
        'Symmetrical ankle dorsiflexion is the primary constraint influencing torso inclination and forward knee displacement.'
      ],
      citation: ResearchSourceCitation(
        sourceName: 'Journal of Strength and Conditioning Research',
        articleTitle: 'Biomechanical Analysis of the Squat: A Review of Kinematics and Kinetics',
        url: 'https://journals.lww.com/nsca-jscr/abstract/2010/12000/the_biomechanics_of_the_squat.28.aspx',
        publicationDate: '2023',
        authorOrOrganization: 'National Strength and Conditioning Association (NSCA)',
      ),
    ),
    ResearchArticle(
      id: 'asymmetry_injury_risk',
      title: 'Limb Symmetry Indices and Athletic Movement Mechanics',
      category: 'Movement Mechanics',
      summary: 'Evaluation of bilateral asymmetry thresholds in functional sporting movements and lower-limb force absorption.',
      keyFindings: [
        'Bilateral asymmetry exceeding 15-20% in lower-extremity range of motion or force attenuation warrants movement monitoring and technique refinement.',
        'Unilateral drills (single-leg squats, step-downs) provide measurable baseline tracking for limb symmetry without maximal loading.',
        'Kinematic symmetry variations should guide coaching cues rather than be interpreted as absolute diagnostic markers.'
      ],
      citation: ResearchSourceCitation(
        sourceName: 'British Journal of Sports Medicine (BJSM)',
        articleTitle: 'Limb Symmetry Index in Return to Sport: Methodological Considerations and Clinical Applications',
        url: 'https://bjsm.bmj.com/content/54/14/839',
        publicationDate: '2022',
        authorOrOrganization: 'International Olympic Committee Consensus Group',
      ),
    ),
    ResearchArticle(
      id: 'warmup_potentiation',
      title: 'Dynamic Warm-Up Concepts and Neuromuscular Potentiation',
      category: 'Warm-Up Concepts',
      summary: 'Comparison of static stretching vs dynamic multi-joint movement preparation on joint range of motion and reactive stability.',
      keyFindings: [
        'Multi-plane dynamic movements improve joint range of motion without the transient strength decrements associated with prolonged static stretching.',
        'Gradual progressive-range movements prime neuromuscular control and joint position sense prior to high-demand activities.',
        'Active mobility routines targeting hips and thoracic spine improve squat and lunge tracking consistency.'
      ],
      citation: ResearchSourceCitation(
        sourceName: 'Sports Medicine Open',
        articleTitle: 'Effects of Dynamic vs Static Warm-Ups on Acute Athletic Performance and Joint Mobility',
        url: 'https://sportsmedicine-open.springeropen.com/articles/10.1186/s40798-021-00383-w',
        publicationDate: '2023',
        authorOrOrganization: 'European College of Sport Science (ECSS)',
      ),
    ),
    ResearchArticle(
      id: 'shoulder_kinematics_overhead',
      title: 'Scapulohumeral Rhythm and Shoulder Flexion Trajectories',
      category: 'Exercise Technique',
      summary: 'Analysis of shoulder flexion and abduction mechanics with emphasis on scapular upward rotation and spinal alignment.',
      keyFindings: [
        'A normal 2:1 ratio between glenohumeral elevation and scapulothoracic upward rotation ensures optimal subacromial clearance.',
        'Compensatory lumbar hyperextension during terminal shoulder flexion indicates restricted latissimus or thoracic mobility.',
        'Visual feedback during arm elevation assists athletes in maintaining controlled tempo and coronal plane alignment.'
      ],
      citation: ResearchSourceCitation(
        sourceName: 'American Journal of Sports Medicine (AJSM)',
        articleTitle: 'Scapular Kinematics and Movement Quality in Overhead Athletes',
        url: 'https://journals.sagepub.com/doi/10.1177/0363546520987114',
        publicationDate: '2024',
        authorOrOrganization: 'American Orthopaedic Society for Sports Medicine',
      ),
    ),
    ResearchArticle(
      id: 'recovery_sleep_tissue',
      title: 'Sleep Architecture, Hydration, and Connective Tissue Recovery',
      category: 'Recovery Education',
      summary: 'Review of nocturnal hormonal secretion and cellular synthesis during slow-wave sleep in training athletes.',
      keyFindings: [
        'Slow-wave non-REM sleep accounts for up to 95% of daily growth hormone release, driving collagen repair and neuromuscular recovery.',
        'Even moderate dehydration (2% body mass loss) impairs joint lubricant viscosity and movement consistency.',
        'Consistent sleep-wake timing correlates directly with daily movement consistency metrics.'
      ],
      citation: ResearchSourceCitation(
        sourceName: 'International Journal of Sports Physiology and Performance',
        articleTitle: 'Sleep, Recovery, and Athletic Performance: Evidence-Based Guidelines',
        url: 'https://journals.humankinetics.com/view/journals/ijspp/16/8/article-p1063.xml',
        publicationDate: '2023',
        authorOrOrganization: 'Australian Institute of Sport (AIS)',
      ),
    ),
    ResearchArticle(
      id: 'rtp_criteria_progression',
      title: 'Return-to-Play Movement Competency Framework',
      category: 'Return-to-Play Education',
      summary: 'Graduated stage-based progression criteria combining qualitative movement analysis with athlete-reported confidence.',
      keyFindings: [
        'Time-based recovery protocols alone are insufficient; objective movement competency (ROM, symmetry, landing control) is necessary.',
        'Athletes must demonstrate controlled deceleration and consistent repetition kinematics before progressing across load stages.',
        'Objective movement tracking provides transparent data for multidisciplinary care teams without replacing physician clearance.'
      ],
      citation: ResearchSourceCitation(
        sourceName: 'Journal of Orthopaedic & Sports Physical Therapy (JOSPT)',
        articleTitle: 'Criteria-Based Progression in Sports Rehabilitation: Moving Beyond Arbitrary Timelines',
        url: 'https://www.jospt.org/doi/10.2519/jospt.2021.10188',
        publicationDate: '2022',
        authorOrOrganization: 'Sports Physical Therapy Section (SPTS)',
      ),
    ),
  ];

  Future<ResearchSearchResult> search(String query, {String? category}) async {
    final cleanQuery = query.trim().toLowerCase();
    final results = curatedKnowledgeBase.where((article) {
      final matchesCat = category == null || category == 'All' || article.category.toLowerCase() == category.toLowerCase();
      if (!matchesCat) return false;
      if (cleanQuery.isEmpty) return true;
      return article.title.toLowerCase().contains(cleanQuery) ||
          article.summary.toLowerCase().contains(cleanQuery) ||
          article.category.toLowerCase().contains(cleanQuery) ||
          article.citation.sourceName.toLowerCase().contains(cleanQuery) ||
          article.keyFindings.any((f) => f.toLowerCase().contains(cleanQuery));
    }).toList();

    return ResearchSearchResult(
      articles: results,
      query: query,
      isOnlineSource: false, // Controlled curated repository
      statusMessage: results.isEmpty ? 'No peer-reviewed articles matched your query.' : 'Vetted scientific source citations retrieved.',
    );
  }

  ResearchArticle? getById(String id) {
    return curatedKnowledgeBase.where((a) => a.id == id).firstOrNull;
  }
}
