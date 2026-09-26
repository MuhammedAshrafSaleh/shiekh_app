      final data = await _client
          .from('lesson_quiz_questions')
          .select()
          .eq('lesson_id', lessonId)
          .order('order_index', ascending: true)
          .limit(50);
      return Right((data as List)
          .map((e) =>
              AdminQuizQuestionEntity.fromJson(e as Map<String, dynamic>))
          .toList());