// lib/features/onboarding/data/onboarding_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/onboarding_slide_entity.dart';

class OnboardingRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('OnboardingRepository');

  OnboardingRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<OnboardingSlideEntity>>> getSlides() async {
    final net = _checkNetwork<List<OnboardingSlideEntity>>();
    if (net != null) return net;

    try {
      final raw = await _client
          .from('onboarding_slides')
          .select()
          .eq('is_active', true)
          .order('order_index')
          .limit(50);

      final slides = (raw as List)
          .map((e) => OnboardingSlideEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return Right(slides);
    } on PostgrestException catch (e) {
      _log.warning('getSlides: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
