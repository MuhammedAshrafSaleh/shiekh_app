// lib/features/admin/sections/cubit/admin_sections_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_section_repository.dart';
import 'admin_sections_state.dart';

class AdminSectionsCubit extends Cubit<AdminSectionsState> {
  final AdminSectionRepository _repo;

  AdminSectionsCubit(this._repo) : super(AdminSectionsInitial());

  Future<void> load() async {
    emit(AdminSectionsLoading());
    final result = await _repo.getSections();
    result.fold(
      (f) => emit(AdminSectionsError(f.message)),
      (sections) => emit(AdminSectionsLoaded(sections)),
    );
  }

  Future<void> createSection({
    required String name,
    required String icon,
    String? description,
  }) async {
    final result = await _repo.createSection(
      name: name,
      icon: icon,
      description: description,
    );
    result.fold(
      (f) => emit(AdminSectionsError(f.message)),
      (_) => emit(AdminSectionMutationSuccess()),
    );
  }

  Future<void> updateSection({
    required String id,
    required String name,
    required String icon,
    String? description,
  }) async {
    final result = await _repo.updateSection(
      id: id,
      name: name,
      icon: icon,
      description: description,
    );
    result.fold(
      (f) => emit(AdminSectionsError(f.message)),
      (_) => emit(AdminSectionMutationSuccess()),
    );
  }

  Future<void> deleteSection(String id) async {
    final result = await _repo.deleteSection(id);
    result.fold((f) => emit(AdminSectionsError(f.message)), (_) => load());
  }
}
