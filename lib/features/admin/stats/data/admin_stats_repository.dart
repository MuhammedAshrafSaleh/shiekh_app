      final data = await _client
          .from('lessons')
          .select()
          .eq('book_id', bookId)
          .order('order_index', ascending: true)
          .limit(200);
      return Right((data as List)
          .map((e) => LessonEntity.fromJson(e as Map<String, dynamic>))