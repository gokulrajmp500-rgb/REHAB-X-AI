const supportedSports = [
  'Athletics',
  'Football',
  'Cricket',
  'Basketball',
  'Volleyball',
  'Badminton',
  'Tennis',
  'Hockey',
  'Kabaddi',
  'Swimming',
  'Boxing',
  'Wrestling',
  'Cycling',
  'Running',
  'Gymnastics',
  'Other',
];

class AthleteProfile {
  const AthleteProfile({
    required this.name,
    this.sport = '',
    this.position = '',
    this.recoveryStage = 'Mobility',
    this.age = 0,
    this.experienceYears = 0,
    this.heightCm = '',
    this.weightKg = '',
    this.dominantHand = 'Right',
    this.dominantLeg = 'Right',
    this.trainingExperience = 'Intermediate',
    this.competitionLevel = 'Club / Regional',
    this.trainingTime = '07:00 AM',
    this.sleepTime = '10:30 PM',
    this.wakeTime = '06:00 AM',
    this.fitnessGoals = 'Improve movement symmetry and mobility',
    this.knownLimitations = '',
    this.coach = '',
    this.emergencyContact = '',
    this.photoPath = '',
    this.avatarId = '1',
  });

  final String name;
  final String sport;
  final String position;
  final String recoveryStage;
  final int age;
  final int experienceYears;
  final String heightCm;
  final String weightKg;
  final String dominantHand;
  final String dominantLeg;
  final String trainingExperience;
  final String competitionLevel;
  final String trainingTime;
  final String sleepTime;
  final String wakeTime;
  final String fitnessGoals;
  final String knownLimitations;
  final String coach;
  final String emergencyContact;
  final String photoPath;
  final String avatarId;

  Map<String, Object?> toJson() => {
    'name': name,
    'sport': sport,
    'position': position,
    'recoveryStage': recoveryStage,
    'age': age,
    'experienceYears': experienceYears,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'dominantHand': dominantHand,
    'dominantLeg': dominantLeg,
    'trainingExperience': trainingExperience,
    'competitionLevel': competitionLevel,
    'trainingTime': trainingTime,
    'sleepTime': sleepTime,
    'wakeTime': wakeTime,
    'fitnessGoals': fitnessGoals,
    'knownLimitations': knownLimitations,
    'coach': coach,
    'emergencyContact': emergencyContact,
    'photoPath': photoPath,
    'avatarId': avatarId,
  };

  factory AthleteProfile.fromJson(Map<String, Object?> json) => AthleteProfile(
    name: json['name'] as String? ?? '',
    sport: json['sport'] as String? ?? '',
    position: json['position'] as String? ?? '',
    recoveryStage: json['recoveryStage'] as String? ?? 'Mobility',
    age: (json['age'] as num?)?.toInt() ?? 0,
    experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
    heightCm: json['heightCm'] as String? ?? '',
    weightKg: json['weightKg'] as String? ?? '',
    dominantHand: json['dominantHand'] as String? ?? 'Right',
    dominantLeg: json['dominantLeg'] as String? ?? 'Right',
    trainingExperience: json['trainingExperience'] as String? ?? 'Intermediate',
    competitionLevel: json['competitionLevel'] as String? ?? 'Club / Regional',
    trainingTime: json['trainingTime'] as String? ?? '07:00 AM',
    sleepTime: json['sleepTime'] as String? ?? '10:30 PM',
    wakeTime: json['wakeTime'] as String? ?? '06:00 AM',
    fitnessGoals: json['fitnessGoals'] as String? ?? 'Improve movement symmetry and mobility',
    knownLimitations: json['knownLimitations'] as String? ?? '',
    coach: json['coach'] as String? ?? '',
    emergencyContact: json['emergencyContact'] as String? ?? '',
    photoPath: json['photoPath'] as String? ?? '',
    avatarId: json['avatarId'] as String? ?? '1',
  );
}