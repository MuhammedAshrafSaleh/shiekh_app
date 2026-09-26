      final booksRaw = await _client
          .from('books')
          .select()
          .eq('section_id', sectionId)
          .eq('status', 'published')
          .order('title', ascending: true)
          .limit(50);

      final books = (booksRaw as List)
          .map((e) => BookEntity.fromJson(e as Map<String, dynamic>))