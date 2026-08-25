// lib/features/lesson/data/video_stream_repository.dart
import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/errors/failures.dart';

/// Resolves a YouTube video URL to a directly-playable muxed stream URL and
/// caches the result for the session so re-opening a lesson (or switching tabs)
/// is instant. Concurrent/repeat requests for the same video share one in-flight
/// extraction — no duplicate work. Failures are not cached (retryable).
class VideoStreamRepository {
  static final _log = Logger('VideoStreamRepository');

  final Map<String, Future<Either<Failure, String>>> _cache = {};

  /// Warms the cache ahead of time (fire-and-forget) so the URL is ready before
  /// the student opens the video tab.
  void prefetch(String videoUrl) {
    unawaited(resolveStreamUrl(videoUrl));
  }

  /// Resolves the direct stream URL for [videoUrl]. Shares the in-flight future
  /// for concurrent callers; returns the cached URL on subsequent calls.
  Future<Either<Failure, String>> resolveStreamUrl(String videoUrl) {
    final videoId = VideoId.parseVideoId(videoUrl);
    if (videoId == null) {
      return Future.value(
        Left(ValidationFailure('رابط الفيديو غير صحيح، تواصل مع الإدارة')),
      );
    }
    return _cache.putIfAbsent(videoId, () => _extract(videoId));
  }

  Future<Either<Failure, String>> _extract(String videoId) async {
    final yt = YoutubeExplode();
    try {
      // android client returns the muxed stream directly; pinning to it avoids
      // the ios client's slow 403-retry storm. requireWatchPage:false trims a
      // round-trip.
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.android],
        requireWatchPage: false,
      );
      final muxed = manifest.muxed;
      if (muxed.isEmpty) {
        _cache.remove(videoId);
        return Left(ServerFailure('تعذّر تشغيل الفيديو داخل التطبيق'));
      }
      return Right(muxed.withHighestBitrate().url.toString());
    } on Exception catch (e, s) {
      _log.warning('resolveStreamUrl failed for $videoId', e, s);
      _cache.remove(videoId); // don't cache failures — allow a retry
      return Left(ServerFailure('تعذّر تشغيل الفيديو داخل التطبيق'));
    } finally {
      yt.close();
    }
  }
}
