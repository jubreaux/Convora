// ===== Auth Models =====
class User {
  final int id;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;
  final int? orgId;
  final String? orgRole;
  final String? preferredVoice;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.orgId,
    this.orgRole,
    this.preferredVoice,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      orgId: json['org_id'] as int?,
      orgRole: json['org_role'] as String?,
      preferredVoice: json['preferred_voice'] as String?,
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

class ScenarioContext {
  final int id;
  final String name;

  ScenarioContext({
    required this.id,
    required this.name,
  });

  factory ScenarioContext.fromJson(Map<String, dynamic> json) {
    return ScenarioContext(
      id: json['id'] as int,
      name: json['name'] as String,
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
  final String visibility;
  final DateTime createdAt;

  ScenarioList({
    required this.id,
    required this.title,
    required this.discType,
    this.transactionType,
    required this.visibility,
    required this.createdAt,
  });

  factory ScenarioList.fromJson(Map<String, dynamic> json) {
    return ScenarioList(
      id: json['id'] as int,
      title: json['title'] as String,
      discType: json['disc_type'] as String,
      transactionType: json['transaction_type'] as String?,
      visibility: json['visibility'] as String? ?? 'personal',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ScenarioDetail {
  final int id;
  final String title;
  final String discType;
  final String aiSystemPrompt;
  final String visibility;
  final DateTime createdAt;
  final List<Objective> objectives;
  final int? personalityTemplateId;
  final int? traitSetId;
  final int? scenarioContextId;

  ScenarioDetail({
    required this.id,
    required this.title,
    required this.discType,
    required this.aiSystemPrompt,
    required this.visibility,
    required this.createdAt,
    required this.objectives,
    this.personalityTemplateId,
    this.traitSetId,
    this.scenarioContextId,
  });

  factory ScenarioDetail.fromJson(Map<String, dynamic> json) {
    return ScenarioDetail(
      id: json['id'] as int,
      title: json['title'] as String,
      discType: json['disc_type'] as String,
      aiSystemPrompt: json['ai_system_prompt'] as String,
      visibility: json['visibility'] as String? ?? 'personal',
      createdAt: DateTime.parse(json['created_at'] as String),
      objectives: (json['objectives'] as List? ?? [])
          .map((e) => Objective.fromJson(e as Map<String, dynamic>))
          .toList(),
      personalityTemplateId: json['personality_template_id'] as int?,
      traitSetId: json['trait_set_id'] as int?,
      scenarioContextId: json['scenario_context_id'] as int?,
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
  final int maxScore;
  final List<SessionObjective> objectivesCompleted;
  final bool appointmentSet;
  final String? audioBase64;  // MP3 audio encoded as base64 (if voice=true)

  SessionMessageResponse({
    required this.reply,
    required this.currentScore,
    required this.maxScore,
    required this.objectivesCompleted,
    required this.appointmentSet,
    this.audioBase64,
  });

  factory SessionMessageResponse.fromJson(Map<String, dynamic> json) {
    return SessionMessageResponse(
      reply: json['reply'] as String,
      currentScore: json['current_score'] as int,
      maxScore: (json['max_score'] as int?) ?? 0,
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

class ScoreEvent {
  final int id;
  final String eventType;
  final int points;
  final String? label;
  final String? reason;
  final DateTime createdAt;

  ScoreEvent({
    required this.id,
    required this.eventType,
    required this.points,
    this.label,
    this.reason,
    required this.createdAt,
  });

  factory ScoreEvent.fromJson(Map<String, dynamic> json) {
    return ScoreEvent(
      id: json['id'] as int,
      eventType: json['event_type'] as String,
      points: json['points'] as int,
      label: json['label'] as String?,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SessionReviewResponse {
  final int id;
  final int scenarioId;
  final String scenarioTitle;
  final String status;
  final int finalScore;
  final bool appointmentSet;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String discType;
  final PersonalityTemplate personality;
  final TraitSet traitSet;
  final List<SessionObjective> objectives;
  final List<SessionMessage> messages;
  final List<ScoreEvent> scoreEvents;

  SessionReviewResponse({
    required this.id,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.status,
    required this.finalScore,
    required this.appointmentSet,
    required this.startedAt,
    this.endedAt,
    required this.discType,
    required this.personality,
    required this.traitSet,
    required this.objectives,
    required this.messages,
    required this.scoreEvents,
  });

  factory SessionReviewResponse.fromJson(Map<String, dynamic> json) {
    return SessionReviewResponse(
      id: json['id'] as int,
      scenarioId: json['scenario_id'] as int,
      scenarioTitle: json['scenario_title'] as String,
      status: json['status'] as String,
      finalScore: json['final_score'] as int,
      appointmentSet: json['appointment_set'] as bool,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      discType: json['disc_type'] as String,
      personality: PersonalityTemplate.fromJson(
          json['personality'] as Map<String, dynamic>),
      traitSet: TraitSet.fromJson(json['trait_set'] as Map<String, dynamic>),
      objectives: (json['objectives'] as List)
          .map((e) => SessionObjective.fromJson(e as Map<String, dynamic>))
          .toList(),
      messages: (json['messages'] as List)
          .map((e) => SessionMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      scoreEvents: (json['score_events'] as List)
          .map((e) => ScoreEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ===== User Stats Models =====
class TimelinePoint {
  final DateTime sessionDate;
  final int score;
  final String scenarioTitle;
  final String discType;

  TimelinePoint({
    required this.sessionDate,
    required this.score,
    required this.scenarioTitle,
    required this.discType,
  });

  factory TimelinePoint.fromJson(Map<String, dynamic> json) {
    return TimelinePoint(
      sessionDate: DateTime.parse(json['session_date'] as String),
      score: json['score'] as int,
      scenarioTitle: json['scenario_title'] as String,
      discType: json['disc_type'] as String,
    );
  }
}

class DiscTypeStats {
  final int sessionCount;
  final double avgScore;
  final int bestScore;

  DiscTypeStats({
    required this.sessionCount,
    required this.avgScore,
    required this.bestScore,
  });

  factory DiscTypeStats.fromJson(Map<String, dynamic> json) {
    return DiscTypeStats(
      sessionCount: json['session_count'] as int,
      avgScore: (json['avg_score'] as num).toDouble(),
      bestScore: json['best_score'] as int,
    );
  }
}

class ScenarioPerformance {
  final String scenarioTitle;
  final int sessionCount;
  final double avgScore;
  final int bestScore;

  ScenarioPerformance({
    required this.scenarioTitle,
    required this.sessionCount,
    required this.avgScore,
    required this.bestScore,
  });

  factory ScenarioPerformance.fromJson(Map<String, dynamic> json) {
    return ScenarioPerformance(
      scenarioTitle: json['scenario_title'] as String,
      sessionCount: json['session_count'] as int,
      avgScore: (json['avg_score'] as num).toDouble(),
      bestScore: json['best_score'] as int,
    );
  }
}

class TopScenarioStats {
  final int scenarioId;
  final String title;
  final int totalSessions;
  final double avgScore;
  final String discType;

  TopScenarioStats({
    required this.scenarioId,
    required this.title,
    required this.totalSessions,
    required this.avgScore,
    required this.discType,
  });

  factory TopScenarioStats.fromJson(Map<String, dynamic> json) {
    return TopScenarioStats(
      scenarioId: json['scenario_id'] as int,
      title: json['title'] as String,
      totalSessions: json['total_sessions'] as int,
      avgScore: (json['avg_score'] as num).toDouble(),
      discType: json['disc_type'] as String,
    );
  }
}

class UserStats {
  final int totalSessions;
  final double avgScore;
  final int bestScore;
  final int totalObjectivesCompleted;
  final double appointmentRate;
  final List<TimelinePoint> timeline;
  final Map<String, DiscTypeStats> discBreakdown;
  final List<ScenarioPerformance> scenarioPerformance;
  final List<TopScenarioStats> topScenarios;

  UserStats({
    required this.totalSessions,
    required this.avgScore,
    required this.bestScore,
    required this.totalObjectivesCompleted,
    required this.appointmentRate,
    required this.timeline,
    required this.discBreakdown,
    required this.scenarioPerformance,
    this.topScenarios = const [],
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalSessions: json['total_sessions'] as int,
      avgScore: (json['avg_score'] as num).toDouble(),
      bestScore: json['best_score'] as int,
      totalObjectivesCompleted: json['total_objectives_completed'] as int,
      appointmentRate: (json['appointment_rate'] as num).toDouble(),
      timeline: (json['timeline'] as List)
          .map((e) => TimelinePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      discBreakdown: {
        for (var entry in (json['disc_breakdown'] as Map).entries)
          entry.key as String: DiscTypeStats.fromJson(entry.value as Map<String, dynamic>)
      },
      scenarioPerformance: (json['scenario_performance'] as List)
          .map((e) => ScenarioPerformance.fromJson(e as Map<String, dynamic>))
          .toList(),
      topScenarios: json['top_scenarios'] != null
          ? (json['top_scenarios'] as List)
              .map((e) => TopScenarioStats.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}
