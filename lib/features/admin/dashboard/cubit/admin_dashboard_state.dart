// lib/features/admin/dashboard/cubit/admin_dashboard_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/book_entity.dart';
import '../data/admin_dashboard_repository.dart';

abstract class AdminDashboardState extends Equatable {
  const AdminDashboardState();
  @override
  List<Object?> get props => [];
}

class AdminDashboardInitial extends AdminDashboardState {}

class AdminDashboardLoading extends AdminDashboardState {}

class AdminDashboardLoaded extends AdminDashboardState {
  final AdminStats stats;
  final List<BookEntity> books;

  const AdminDashboardLoaded({required this.stats, required this.books});

  @override
  List<Object?> get props => [stats, books];
}

class AdminDashboardDeleteSuccess extends AdminDashboardState {}

class AdminDashboardError extends AdminDashboardState {
  final String message;
  const AdminDashboardError(this.message);
  @override
  List<Object?> get props => [message];
}
