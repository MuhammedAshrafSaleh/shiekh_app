          .select()
          .eq('book_id', bookId)
          .eq('status', 'published')
          .gt('order_index', currentOrderIndex)
          .order('order_index', ascending: true)
          .limit(1);

      final rows = response as List;