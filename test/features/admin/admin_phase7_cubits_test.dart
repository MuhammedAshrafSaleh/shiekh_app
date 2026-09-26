        await expectation;
      });
    });

    // ── answerQuestion ────────────────────────────────────────────────────────
    group('answerQuestion', () {
      test('returns true and reloads on success', () async {
        when(() => repo.answerQuestion(
              questionId: any(named: 'questionId'),
              answerText: any(named: 'answerText'),
            )).thenAnswer((_) async => Right(_answeredQ));
        when(() => repo.getQuestions(status: 'pending', limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => const Right([]));
        when(() => repo.getQuestions(status: 'answered', limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => Right([_answeredQ]));

        final ok = await cubit.answerQuestion(
          questionId: 'sq-1',
          answerText: 'إجابة الشيخ',
        );
        expect(ok, isTrue);
      });

      test('returns false and emits Error on failure', () async {
        when(() => repo.answerQuestion(
              questionId: any(named: 'questionId'),
              answerText: any(named: 'answerText'),
            )).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminQaError>()),
        );
        final ok = await cubit.answerQuestion(
          questionId: 'sq-1',
          answerText: 'إجابة',
        );
        await expectation;
        expect(ok, isFalse);
        expect((cubit.state as AdminQaError).message, _serverFailure.message);
      });
    });
  });

  // ===========================================================================
  // AdminStatsCubit