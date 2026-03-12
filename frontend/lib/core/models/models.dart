// ===== Auth Models =====
class User {
  final int id;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

// ===== Scenario Models =====
class PersonalityTemplate {
  final int id;
  final String occupation;
  final String? recreation;
  final String? family;
  final String? pets;
  final String transactionType;
  final String? buyCriteria;
  final String? sellCriteria;
  final String? surfaceMotivation;
  final String? hiddenMotivation;
  final String? timeframe;
  final String? redFlags;

  PersonalityTemplate({
    required this.id,
    required this.occupation,
    this.recreation,
    this.family,
    this.pets,
    required this.transactionType,
    this.buyCriteria,
    this.sellCriteria,
    this.surfaceMotivation,
    this.hiddenMotivation,
    this.timeframe,
    this.redFlags,
  });

  factory PersonalityTemplate.fromJson(Map<String, dynamic> json) {
    return PersonalityTemplate(
      id: json['id'] as int,
      occupation: json['occupation'] as String,
      recreation: json['recreation'] as String?,
      family: json['family'] as String?,
      pets: json['pets'] as String?,
      transactionType: json['transaction_type'] as String,
      buyCriteria: json['buy_criteria'] as String?,
      sellCriteria: json['sell_criteria'] as String?,
      surfaceMotivation: json['surface_motivation'] as String?,
      hiddenMotivation: json['hidden_motivation'] as String?,
      timeframe: json['timeframe'] as String?,
      redFlags: json['red_flags'] as String?,
    );
  }
}

class TraitSet {
  final int id;
  final int traitSetNumber;
  final String trait1;
  final String trait2;
  final String trait3;

  TraitSet({
    required this.id,
    required this.traitSetNumber,
    required this.trait1,
    required this.trait2,
    required this.trait3,
  });

  factory TraitSet.fromJson(Map<String, dynamic> json) {
    return TraitSet(
      id: json['id'] as int,
      traitSetNumber: json['trait_set_number'] as int,
      trait1: json['trait_1'] as String,
      trait2: json['trait_2'] as String,
      trait3: json['trait_3'] as String,
    );
  }
}

class Objective {
  final int id;
  final String label;
  final String? description;
  final int maxPoints;

  Objective({
    required this.id,
    required this.label,
    this.description,
    required this.maxPoints,
  });

  factory Objective.fromJson(Map<String, dynamic> json) {
    return Objective(
      id: json['id'] as int,
      label: json['label'] as String,
      description: json['description'] as String?,
      maxPoints: json['max_points'] as int,
    );
  }
}

class ScenarioList {
  final int id;
  final String title;
  final String discType;
  final String? transactionType;
  final bool isPublic;
  final DateTime createdAt;

  ScenarioList({
    required this.id,
    required this.title,
    required this.discType,
    this.transactionType,
    required this.isPublic,
    required this.createdAt,
  });

  factory ScenarioList.fromJson(Map<String, dynamic> json) {
    return ScenarioList(
      id: json['id'] as int,
      title: json['title'] as String,
      discType: json['disc_type'] as String,
      transactionType: json['transaction_type'] as String?,
      isPublic: json['is_public'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ===== Session Models =====
class SessionMessage {
  final int id;
  final String role;
  final String content;
  final DateTime createdAt;

  SessionMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory SessionMessage.fromJson(Map<String, dynamic> json) {
    return SessionMessage(
      id: json['id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SessionObjective {
  final int id;
  final Objective objective;
  final bool achieved;
  final int pointsAwarded;
  final String? notes;
  final DateTime? achievedAt;

  SessionObjective({
    required this.id,
    required this.objective,
    required this.achieved,
    required this.pointsAwarded,
    this.notes,
    this.achievedAt,
  });

  factory SessionObjective.fromJson(Map<String, dynamic> json) {
    return SessionObjective(
      id: json['id'] as int,
      objective: Objective.fromJson(json['objective'] as Map<String, dynamic>),
      achieved: json['achieved'] as bool,
      pointsAwarded: json['points_awarded'] as int,
      notes: json['notes'] as String?,
      achievedAt: json['achieved_at'] != null
          ? DateTime.parse(json['achieved_at'] as String)
          : null,
    );
  }
}

class SessionMessageResponse {
  final String reply;
  final int currentScore;
  final List<SessionObjective> objectivesCompleted;
  final bool appointmentSet;
  final String? audioBase64;  // MP3 audio encoded as base64 (if voice=true)

  SessionMessageResponse({
    required this.reply,
    required this.currentScore,
    required this.objectivesCompleted,
    required this.appointmentSet,
    this.audioBase64,
  });

  factory SessionMessageResponse.fromJson(Map<String, dynamic> json) {
    return SessionMessageResponse(
      reply: json['reply'] as String,
      currentScore: json['current_score'] as int,
      objectivesCompleted: (json['objectives_completed'] as List)
          .map((e) => SessionObjective.fromJson(e as Map<String, dynamic>))
          .toList(),
      appointmentSet: json['appointment_set'] as bool,
      audioBase64: json['audio_base64'] as String?,
    );
  }
}

class SessionEndResponse {
  final int finalScore;
  final PersonalityTemplate personality;
  final TraitSet traitSet;
  final String discType;
  final List<SessionObjective> objectives;
  final List<SessionMessage> messages;
  final bool appointmentSet;

  SessionEndResponse({
    required this.finalScore,
    required this.personality,
    required this.traitSet,
    required this.discType,
    required this.objectives,
    required this.messages,
    required this.appointmentSet,
  });

  factory SessionEndResponse.fromJson(Map<String, dynamic> json) {
    return SessionEndResponse(
      finalScore: json['final_score'] as int,
      personality: PersonalityTemplate.fromJson(
          json['personality'] as Map<String, dynamic>),
      traitSet: TraitSet.fromJson(json['trait_set'] as Map<String, dynamic>),
      discType: json['disc_type'] as String,
      objectives: (json['objectives'] as List)
          .map((e) => SessionObjective.fromJson(e as Map<String, dynamic>))
          .toList(),
      messages: (json['messages'] as List)
          .map((e) => SessionMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      appointmentSet: json['appointment_set'] as bool,
    );
  }
}

class SessionHistory {
  final int id;
  final int scenarioId;
  final String scenarioTitle;
  final String status;
  final int score;
  final DateTime startedAt;
  final DateTime? endedAt;

  SessionHistory({
    required this.id,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.status,
    required this.score,
    required this.startedAt,
    this.endedAt,
  });

  factory SessionHistory.fromJson(Map<String, dynamic> json) {
    return SessionHistory(
      id: json['id'] as int,
      scenarioId: json['scenario_id'] as int,
      scenarioTitle: json['scenario_title'] as String,
      status: json['status'] as String,
      score: json['score'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
    );
  }
}
