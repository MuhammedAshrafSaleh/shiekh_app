      final data = await _client
          .from('home_banners')
          .select()
          .order('order_index', ascending: true)
          .limit(50);
      return Right((data as List)
          .map((e) => BannerEntity.fromJson(e as Map<String, dynamic>))
          .toList());
    } on PostgrestException catch (e) {
      _log.warning('getBanners: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<BookEntity>>> getPublishedBooks() async {
    final net = _checkNetwork<List<BookEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('books')
          .select('id, title, section_id, status, review_status, is_featured, featured_order')
          .eq('status', 'published')
          .order('title', ascending: true)
          .limit(200);
      return Right((data as List)
          .map((e) => BookEntity.fromJson(e as Map<String, dynamic>))
          .toList());
    } on PostgrestException catch (e) {