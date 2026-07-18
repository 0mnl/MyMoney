class Goal {
  final String id;
  final String familyId;
  final String name;
  final int targetAmountKopecks;
  final int currentAmountKopecks;
  final DateTime? targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const Goal({
    required this.id,
    required this.familyId,
    required this.name,
    required this.targetAmountKopecks,
    required this.currentAmountKopecks,
    this.targetDate,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  bool get isCompleted => currentAmountKopecks >= targetAmountKopecks;

  int get progressPercent {
    if (targetAmountKopecks <= 0) return 0;
    final raw = (currentAmountKopecks * 100 / targetAmountKopecks).round();
    return raw.clamp(0, 100);
  }

  Goal copyWith({
    String? name,
    int? targetAmountKopecks,
    int? currentAmountKopecks,
    DateTime? targetDate,
    DateTime? updatedAt,
    bool? isDeleted,
    bool clearTargetDate = false,
  }) =>
      Goal(
        id: id,
        familyId: familyId,
        name: name ?? this.name,
        targetAmountKopecks: targetAmountKopecks ?? this.targetAmountKopecks,
        currentAmountKopecks: currentAmountKopecks ?? this.currentAmountKopecks,
        targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
