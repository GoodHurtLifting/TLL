class BadgeDefinition {
  const BadgeDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.isRepeatable,
  });

  final String key;
  final String title;
  final String description;
  final bool isRepeatable;
}

class BadgeKeys {
  static const meatWagon = 'meat_wagon';
  static const lunchLady = 'lunch_lady';
  static const punchCard = 'punch_card';
}

class BadgeDefinitions {
  static const Map<String, BadgeDefinition> stock = {
    BadgeKeys.meatWagon: BadgeDefinition(
      key: BadgeKeys.meatWagon,
      title: 'Meat Wagon',
      description:
          'Awarded each time total lifetime workload crosses another 100,000 lbs.',
      isRepeatable: true,
    ),
    BadgeKeys.lunchLady: BadgeDefinition(
      key: BadgeKeys.lunchLady,
      title: 'Lunch Lady',
      description:
          'Awarded each time a new all-time heaviest squat, bench press, or deadlift set is logged.',
      isRepeatable: true,
    ),
    BadgeKeys.punchCard: BadgeDefinition(
      key: BadgeKeys.punchCard,
      title: 'Punch Card',
      description:
          'Awarded when 3+ workouts are completed per week for 4 consecutive weeks.',
      isRepeatable: true,
    ),
  };
}
