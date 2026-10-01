class CompetitionEvent {
  const CompetitionEvent({
    required this.name,
    required this.sport,
    required this.event,
    required this.date,
    this.startTime = '09:00 AM',
    this.reportingTime = '07:30 AM',
    this.venue = 'Regional Sports Stadium',
    this.venueAddress = '',
    this.travelTime = '45 mins (estimated)',
    this.equipment = 'Uniform, Cleats, Water bottle, Tape',
    this.organizer = 'State Athletics Federation',
    this.instructions = 'Report to holding tent 60 minutes prior to call time. Complete scheduled dynamic warm-up.',
  });

  final String name;
  final String sport;
  final String event;
  final DateTime date;
  final String startTime;
  final String reportingTime;
  final String venue;
  final String venueAddress;
  final String travelTime;
  final String equipment;
  final String organizer;
  final String instructions;

  Map<String, Object?> toJson() => {
    'name': name,
    'sport': sport,
    'event': event,
    'date': date.toIso8601String(),
    'startTime': startTime,
    'reportingTime': reportingTime,
    'venue': venue,
    'venueAddress': venueAddress,
    'travelTime': travelTime,
    'equipment': equipment,
    'organizer': organizer,
    'instructions': instructions,
  };

  factory CompetitionEvent.fromJson(Map<String, Object?> json) => CompetitionEvent(
    name: json['name'] as String? ?? 'Upcoming Championship',
    sport: json['sport'] as String? ?? 'General Sport',
    event: json['event'] as String? ?? 'Main Event',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 7)),
    startTime: json['startTime'] as String? ?? '09:00 AM',
    reportingTime: json['reportingTime'] as String? ?? '07:30 AM',
    venue: json['venue'] as String? ?? 'Sports Arena',
    venueAddress: json['venueAddress'] as String? ?? '',
    travelTime: json['travelTime'] as String? ?? '45 mins (estimated)',
    equipment: json['equipment'] as String? ?? 'Standard sport kit',
    organizer: json['organizer'] as String? ?? '',
    instructions: json['instructions'] as String? ?? '',
  );
}

class PreCompetitionChecklistItem {
  const PreCompetitionChecklistItem({
    required this.id,
    required this.title,
    required this.category,
    this.completed = false,
  });

  final String id;
  final String title;
  final String category;
  final bool completed;

  PreCompetitionChecklistItem copyWith({bool? completed}) => PreCompetitionChecklistItem(
    id: id,
    title: title,
    category: category,
    completed: completed ?? this.completed,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'completed': completed,
  };

  factory PreCompetitionChecklistItem.fromJson(Map<String, Object?> json) => PreCompetitionChecklistItem(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? '',
    completed: json['completed'] as bool? ?? false,
  );
}

const defaultCompetitionChecklist = [
  PreCompetitionChecklistItem(id: 'sleep', title: 'Adequate Sleep (8+ hours planned)', category: 'Recovery'),
  PreCompetitionChecklistItem(id: 'hydration', title: 'Hydration Strategy & Electrolytes', category: 'Nutrition'),
  PreCompetitionChecklistItem(id: 'equipment', title: 'Competition Equipment Checked & Packed', category: 'Gear'),
  PreCompetitionChecklistItem(id: 'shoes', title: 'Competition Shoes & Spikes Inspected', category: 'Gear'),
  PreCompetitionChecklistItem(id: 'documents', title: 'Competition Registration & ID Documents', category: 'Admin'),
  PreCompetitionChecklistItem(id: 'warmup', title: 'Movement Prep & Dynamic Warm-up Scheduled', category: 'Preparation'),
  PreCompetitionChecklistItem(id: 'travel', title: 'Travel Route & Departure Time Planned', category: 'Logistics'),
  PreCompetitionChecklistItem(id: 'reporting', title: 'Reporting Time Confirmed at Venue', category: 'Logistics'),
];
