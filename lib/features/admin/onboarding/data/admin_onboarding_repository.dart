// lib/features/admin/onboarding/data/admin_onboarding_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/onboarding_slide_entity.dart';

class AdminOnboardingRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminOnboardingRepository');

  AdminOnboardingRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  /// All slides incl. inactive (admin RLS returns them via is_admin()).
  Future<Either<Failure, List<OnboardingSlideEntity>>> getAllSlides() async {
    final net = _checkNetwork<List<OnboardingSlideEntity>>();
    if (net != null) return net;
    try {
      final raw = await _client
          .from('onboarding_slides')
          .select()
          .order('order_index', ascending: true)
          .limit(50);
      final slides = (raw as List)
          .map((e) => OnboardingSlideEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(slides);
    } on PostgrestException catch (e) {
      _log.warning('getAllSlides: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, OnboardingSlideEntity>> updateSlide({
    required String id,
    required String mainText,
    String? subText,
  }) async {
    final net = _checkNetwork<OnboardingSlideEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('onboarding_slides')
          .update({
            'main_text': mainText,
            'sub_text': (subText != null && subText.trim().isEmpty)
                ? null
                : subText,
          })
          .eq('id', id)
          .select()
          .single();
      return Right(OnboardingSlideEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateSlide: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, OnboardingSlideEntity>> setActive({
    required String id,
    required bool isActive,
  }) async {
    final net = _checkNetwork<OnboardingSlideEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('onboarding_slides')
          .update({'is_active': isActive})
          .eq('id', id)
          .select()
          .single();
      return Right(OnboardingSlideEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('setActive: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> updateOrder({
    required String id,
    required int orderIndex,
  }) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client
          .from('onboarding_slides')
          .update({'order_index': orderIndex})
          .eq('id', id);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('updateOrder: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
