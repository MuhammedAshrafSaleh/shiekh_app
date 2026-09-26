    if (net != null) return net;
    try {
      final raw =
          await _client.from('sections').select().order('name', ascending: true).limit(50);

      final booksRaw = await _client