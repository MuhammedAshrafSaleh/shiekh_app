// lib/features/admin/banners/cubit/admin_banner_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/banner_entity.dart';
import '../../../../models/book_entity.dart';

abstract class AdminBannerState extends Equatable {
  const AdminBannerState();
  @override
  List<Object?> get props => [];
}

class AdminBannerInitial extends AdminBannerState {}

class AdminBannerLoading extends AdminBannerState {}

class AdminBannerLoaded extends AdminBannerState {
  final List<BannerEntity> banners;
  final List<BookEntity> books; // for the link dropdown

  const AdminBannerLoaded({required this.banners, required this.books});
  @override
  List<Object?> get props => [banners, books];
}

class AdminBannerError extends AdminBannerState {
  final String message;
  const AdminBannerError(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminBannerMutationSuccess extends AdminBannerState {}
