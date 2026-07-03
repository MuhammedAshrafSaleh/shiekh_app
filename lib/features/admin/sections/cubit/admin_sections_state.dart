// lib/features/admin/sections/cubit/admin_sections_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/section_entity.dart';

abstract class AdminSectionsState extends Equatable {
  const AdminSectionsState();
  @override
  List<Object?> get props => [];
}

class AdminSectionsInitial extends AdminSectionsState {}

class AdminSectionsLoading extends AdminSectionsState {}

class AdminSectionsLoaded extends AdminSectionsState {
  final List<SectionEntity> sections;
  const AdminSectionsLoaded(this.sections);
  @override
  List<Object?> get props => [sections];
}

class AdminSectionsError extends AdminSectionsState {
  final String message;
  const AdminSectionsError(this.message);
  @override
  List<Object?> get props => [message];
}

// Used after a mutation so the UI can pop and the parent can refresh
class AdminSectionMutationSuccess extends AdminSectionsState {}
