    });
  });

  // -------------------------------------------------------------------------
  // saveProgress
  // -------------------------------------------------------------------------
  group('saveProgress', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.saveProgress(
        lessonId: 'lesson-id',
        mediaType: MediaType.video,
        positionSeconds: 120,
        completed: false,
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.saveProgress(
        lessonId: 'lesson-id',
        mediaType: MediaType.audio,
        positionSeconds: 60,
        completed: false,
      );

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'upsert failed'),
      );

      final result = await repo.saveProgress(
        lessonId: 'lesson-id',
        mediaType: MediaType.video,
        positionSeconds: 300,
        completed: true,
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getQuizQuestions (CC-18: uses _student view)
  // -------------------------------------------------------------------------
  group('getQuizQuestions', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);