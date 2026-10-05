// test/features/admin/admin_loading_quotes_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/loading_quotes/cubit/admin_loading_quotes_cubit.dart';
import 'package:sheikhy_app/features/admin/loading_quotes/cubit/admin_loading_quotes_state.dart';
import 'package:sheikhy_app/features/admin/loading_quotes/data/admin_loading_quotes_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/loading_quote_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRepo extends Mock implements AdminLoadingQuotesRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _online = ConnectivityState(isOffline: false);
const _offline = ConnectivityState(isOffline: true);

LoadingQuoteEntity _q(String id, int order, {bool active = true}) =>
    LoadingQuoteEntity(
      id: id,
      text: 'نص $id',
      source: null,
      sortOrder: order,
      isActive: active,
    );

void main() {
  // -------------------------------------------------------------------------
  // Cubit
  // -------------------------------------------------------------------------
  group('AdminLoadingQuotesCubit', () {
    late _MockRepo repo;
    late AdminLoadingQuotesCubit cubit;

    setUp(() {
      repo = _MockRepo();
      cubit = AdminLoadingQuotesCubit(repo);
    });

    tearDown(() => cubit.close());

    Future<void> seed(List<LoadingQuoteEntity> quotes) async {
      when(() => repo.getQuotes()).thenAnswer((_) async => Right(quotes));
      await cubit.load();
    }

    AdminLoadingQuotesLoaded loaded() =>
        cubit.state as AdminLoadingQuotesLoaded;

    test('load success emits Loaded with quotes', () async {
      await seed([_q('a', 1), _q('b', 2)]);
      expect(loaded().quotes, hasLength(2));
      expect(loaded().transientSuccess, isNull);
      expect(loaded().transientError, isNull);
    });

    test('load failure emits Error', () async {
      when(
        () => repo.getQuotes(),
      ).thenAnswer((_) async => Left(ServerFailure('تعذّر التحميل')));
      await cubit.load();
      expect(cubit.state, isA<AdminLoadingQuotesError>());
    });

    test('createQuote success emits Saved', () async {
      when(
        () => repo.createQuote(
          text: any(named: 'text'),
          source: any(named: 'source'),
          sortOrder: any(named: 'sortOrder'),
          isActive: any(named: 'isActive'),
        ),
      ).thenAnswer((_) async => Right(_q('new', 1)));

      await cubit.createQuote(
        text: 'نص',
        source: null,
        sortOrder: 1,
        isActive: true,
      );
      expect(cubit.state, isA<AdminLoadingQuotesSaved>());
    });

    test('createQuote failure emits FormError', () async {
      when(
        () => repo.createQuote(
          text: any(named: 'text'),
          source: any(named: 'source'),
          sortOrder: any(named: 'sortOrder'),
          isActive: any(named: 'isActive'),
        ),
      ).thenAnswer((_) async => Left(ServerFailure('تعذّر حفظ النص')));

      await cubit.createQuote(
        text: 'نص',
        source: null,
        sortOrder: 1,
        isActive: true,
      );
      expect(cubit.state, isA<AdminLoadingQuotesFormError>());
    });

    test('updateQuote success emits Saved', () async {
      when(
        () => repo.updateQuote(
          id: any(named: 'id'),
          text: any(named: 'text'),
          source: any(named: 'source'),
          isActive: any(named: 'isActive'),
        ),
      ).thenAnswer((_) async => Right(_q('a', 1)));

      await cubit.updateQuote(
        id: 'a',
        text: 'نص محدث',
        source: null,
        isActive: true,
      );
      expect(cubit.state, isA<AdminLoadingQuotesSaved>());
    });

    test('delete success removes item + success message', () async {
      await seed([_q('a', 1), _q('b', 2)]);
      when(
        () => repo.deleteQuote(any()),
      ).thenAnswer((_) async => const Right(unit));

      await cubit.deleteQuote('a');

      expect(loaded().quotes.map((q) => q.id), ['b']);
      expect(loaded().transientSuccess, 'تم الحذف');
    });

    test('delete failure keeps the list + error message', () async {
      await seed([_q('a', 1), _q('b', 2)]);
      when(
        () => repo.deleteQuote(any()),
      ).thenAnswer((_) async => Left(ServerFailure('تعذّر حذف النص')));

      await cubit.deleteQuote('a');

      expect(loaded().quotes, hasLength(2), reason: 'list not wiped');
      expect(loaded().transientError, 'تعذّر حذف النص');
      expect(loaded().transientSuccess, isNull);
    });

    test('toggleActive updates the row + success message', () async {
      await seed([_q('a', 1, active: true)]);
      when(
        () => repo.setActive(
          id: any(named: 'id'),
          isActive: any(named: 'isActive'),
        ),
      ).thenAnswer((_) async => Right(_q('a', 1, active: false)));

      await cubit.toggleActive(id: 'a', isActive: false);

      expect(loaded().quotes.single.isActive, isFalse);
      expect(loaded().transientSuccess, 'تم إخفاء النص');
    });

    test('toggleActive failure keeps the list + error message', () async {
      await seed([_q('a', 1, active: true)]);
      when(
        () => repo.setActive(
          id: any(named: 'id'),
          isActive: any(named: 'isActive'),
        ),
      ).thenAnswer((_) async => Left(ServerFailure('تعذّر تحديث الحالة')));

      await cubit.toggleActive(id: 'a', isActive: false);

      expect(loaded().quotes.single.isActive, isTrue, reason: 'unchanged');
      expect(loaded().transientError, 'تعذّر تحديث الحالة');
    });

    test('reorder persists new order + success message', () async {
      await seed([_q('a', 1), _q('b', 2), _q('c', 3)]);
      when(
        () => repo.updateOrder(
          id: any(named: 'id'),
          sortOrder: any(named: 'sortOrder'),
        ),
      ).thenAnswer((_) async => const Right(unit));

      // Move first item to the end.
      await cubit.reorder(0, 3);

      expect(loaded().quotes.map((q) => q.id), ['b', 'c', 'a']);
      expect(loaded().quotes.map((q) => q.sortOrder), [1, 2, 3]);
      expect(loaded().transientSuccess, 'تم تحديث الترتيب');
      verify(
        () => repo.updateOrder(
          id: any(named: 'id'),
          sortOrder: any(named: 'sortOrder'),
        ),
      ).called(greaterThan(0));
    });

    test('nextSortOrder is max + 1 (1 when empty)', () async {
      expect(cubit.nextSortOrder, 1);
      await seed([_q('a', 2), _q('b', 5)]);
      expect(cubit.nextSortOrder, 6);
    });
  });

  // -------------------------------------------------------------------------
  // Repository — error mapping (never raw Postgres)
  // -------------------------------------------------------------------------
  group('AdminLoadingQuotesRepository error mapping', () {
    late _MockSupabaseClient client;
    late _MockConnectivityCubit connectivity;
    late AdminLoadingQuotesRepository repo;

    setUp(() {
      client = _MockSupabaseClient();
      connectivity = _MockConnectivityCubit();
      repo = AdminLoadingQuotesRepository(client, connectivity);
    });

    test('offline → NetworkFailure, no query', () async {
      when(() => connectivity.state).thenReturn(_offline);
      final result = await repo.getQuotes();
      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('getQuotes Postgres error → Arabic, not raw', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'raw pg text'));
      final result = await repo.getQuotes();
      result.fold((f) {
        expect(f, isA<ServerFailure>());
        expect(f.message, 'تعذّر تحميل النصوص، حاول مرة أخرى.');
      }, (_) => fail('expected Left'));
    });

    test('deleteQuote Postgres error → Arabic, not raw', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'raw pg text'));
      final result = await repo.deleteQuote('a');
      result.fold((f) {
        expect(f.message, 'تعذّر حذف النص، حاول مرة أخرى.');
      }, (_) => fail('expected Left'));
    });

    test('updateOrder Postgres error → Arabic, not raw', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'raw pg text'));
      final result = await repo.updateOrder(id: 'a', sortOrder: 1);
      result.fold((f) {
        expect(f.message, 'تعذّر تحديث الترتيب، حاول مرة أخرى.');
      }, (_) => fail('expected Left'));
    });
  });
}
