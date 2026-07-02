// lib/features/home/cubit/home_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/banner_entity.dart';
import '../../../models/book_with_progress_entity.dart';

class HomeData extends Equatable {
  final List<BannerEntity> banners;
  final List<BookWithProgressEntity> featuredBooks;

  const HomeData({required this.banners, required this.featuredBooks});

  @override
  List<Object?> get props => [banners, featuredBooks];
}

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  final HomeData data;
  const HomeLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class HomeEmpty extends HomeState {
  const HomeEmpty();
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
