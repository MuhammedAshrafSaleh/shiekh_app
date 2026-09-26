// lib/features/admin/onboarding/cubit/admin_onboarding_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../models/onboarding_slide_entity.dart';
import '../data/admin_onboarding_repository.dart';
import 'admin_onboarding_state.dart';

class AdminOnboardingCubit extends Cubit<AdminOnboardingState> {
  final AdminOnboardingRepository _repo;

  // Cached working copy so mutations can update in place without a full flicker.
  List<OnboardingSlideEntity> _slides = const [];
  int _nonce = 0;

  AdminOnboardingCubit(this._repo) : super(AdminOnboardingInitial());

  Future<void> load() async {
    emit(AdminOnboardingLoading());
    final result = await _repo.getAllSlides();
    result.fold(
      (f) => emit(AdminOnboardingError(f.message)),
      (slides) {
        _slides = slides;
        emit(AdminOnboardingLoaded(List.of(_slides)));
      },
    );
  }

  void _succeed(String message) {
    emit(AdminOnboardingActionSuccess(message, _nonce++));
    emit(AdminOnboardingLoaded(List.of(_slides)));
  }

  void _replace(OnboardingSlideEntity updated) {
    _slides = [
      for (final s in _slides) if (s.id == updated.id) updated else s,
    ];
  }

  Future<void> save({
    required String id,
    required String mainText,
    String? subText,
  }) async {
    final result = await _repo.updateSlide(
      id: id,
      mainText: mainText,
      subText: subText,
    );
    result.fold(
      (f) => emit(AdminOnboardingError(f.message)),
      (updated) {
        _replace(updated);
        _succeed('تم حفظ التعديلات');
      },
    );
  }

  Future<void> toggleActive({
    required String id,
    required bool isActive,
  }) async {
    final result = await _repo.setActive(id: id, isActive: isActive);
    result.fold(
      (f) => emit(AdminOnboardingError(f.message)),
      (updated) {
        _replace(updated);
        _succeed(updated.isActive ? 'تم تفعيل الشاشة' : 'تم إخفاء الشاشة');
      },
    );
  }

  /// Reorders the cached list, reassigns 1-based order_index, and persists every
  /// row whose index changed. Emits the new order immediately for a responsive
  /// drag, then reloads from the server if any write fails.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final working = List.of(_slides);
    final moved = working.removeAt(oldIndex);
    working.insert(newIndex, moved);

    final List<OnboardingSlideEntity> renumbered = [];
    final List<OnboardingSlideEntity> changed = [];
    for (var i = 0; i < working.length; i++) {
      final desiredOrder = i + 1;
      final s = working[i];
      if (s.orderIndex != desiredOrder) {
        final updated = OnboardingSlideEntity(
          id: s.id,
          orderIndex: desiredOrder,
          type: s.type,
          mainText: s.mainText,
          subText: s.subText,
          isActive: s.isActive,
        );
        renumbered.add(updated);
        changed.add(updated);
      } else {
        renumbered.add(s);
      }
    }

    _slides = renumbered;
    emit(AdminOnboardingLoaded(List.of(_slides)));

    for (final s in changed) {
      final result =
          await _repo.updateOrder(id: s.id, orderIndex: s.orderIndex);
      final failed = result.isLeft();
      if (failed) {
        result.fold((f) => emit(AdminOnboardingError(f.message)), (_) {});
        await load();
        return;
      }
    }
    if (changed.isNotEmpty) _succeed('تم تحديث الترتيب');
  }
}
