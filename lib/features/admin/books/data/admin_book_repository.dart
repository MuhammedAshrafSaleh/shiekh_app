    if (net != null) return net;
    try {
      final raw =
          await _client.from('sections').select().order('name', ascending: true).limit(50);
      return Right((raw as List)
          .map((e) => SectionEntity.fromJson(e as Map<String, dynamic>))