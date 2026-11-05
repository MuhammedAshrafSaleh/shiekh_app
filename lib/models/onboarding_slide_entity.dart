// lib/models/onboarding_slide_entity.dart
import 'package:equatable/equatable.dart';

class OnboardingSlideEntity extends Equatable {
  final String id;
  final int orderIndex;
  final String type; // 'hadith' | 'normal'
  final String mainText;
  final String? subText;
  final bool isActive;

  const OnboardingSlideEntity({
    required this.id,
    required this.orderIndex,
    required this.type,
    required this.mainText,
    this.subText,
    required this.isActive,
  });

  bool get isHadith => type == 'hadith';

  factory OnboardingSlideEntity.fromJson(Map<String, dynamic> json) {
    return OnboardingSlideEntity(
      id: json['id'] as String,
      orderIndex: json['order_index'] as int,
      type: json['type'] as String,
      mainText: json['main_text'] as String,
      subText: json['sub_text'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  @override
  List<Object?> get props => [
    id,
    orderIndex,
    type,
    mainText,
    subText,
    isActive,
  ];
}
