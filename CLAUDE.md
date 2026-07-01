# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## App Overview

**Sheikhy (شيخي)** (package: `sheikhy_app`) is a white-label, single-sheikh Islamic education app. One deployment = one scholar (not multi-tenant). Students browse content by scientific section, enroll in books, study lessons (YouTube video / Google Drive audio / Google Drive PDF), take per-lesson quizzes and a book-level final exam, earn certificates, ask the sheikh questions, and receive notifications. The sheikh (a single manually-promoted admin) authors all content from an in-app admin area.

- **Platform:** iOS + Android (Flutter), future Web from the same codebase
- **Backend:** Supabase (PostgreSQL, Auth, Realtime, RLS) — **schema is finalized, do not redesign** (`docs/schema.sql`)
- **Language:** Arabic-only UI, full RTL. No secondary locale in v1.
- **State Management:** BLoC/Cubit (`flutter_bloc`) — Cubit for standard screens, full Bloc for the exam
- **Architecture:** Feature-first, Repository pattern (no separate UseCase layer)
- **Routing:** GoRouter
- **DI:** `RepositoryProvider` tree (no `get_it`/`injectable`)
- **Error handling:** `dartz` `Either<Failure, T>` from every repository method

Source of truth documents live in `docs/`: `PRD.md` (primary reference — features, user flows, 30 corner cases), `BRD_en.md` (business rules), `schema.sql` (database), `Supabase_Setup_Guide.md` (backend setup, already executed and verified), `screens/` (approved UI designs).

---

## Common Commands

```bash
# Run app (debug) — always pass config via dart-define
flutter run --dart-define-from-file=dart_define.json

# Build release APK
flutter build apk --release --dart-define-from-file=dart_define.json

# Analyze code
flutter analyze

# Format code
dart format lib/

# Run all tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Code generation (freezed models, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
dart run build_runner watch --delete-conflicting-outputs
```

---

## Architecture

Feature-first structure. No Domain/Data/Presentation split, no UseCase layer — Cubits/Blocs call Repositories directly.

```
lib/
├── main.dart
├── app/
│   ├── app.dart              # MaterialApp.router, theme, ar locale, RTL
│   ├── router.dart           # go_router + role-based redirect + deep links
│   └── bloc_providers.dart   # RepositoryProvider tree + global BlocProviders
├── core/
│   ├── config/                # app_config.dart (--dart-define vars), brand.dart
│   ├── theme/                 # app_theme.dart (light/dark, ColorScheme.fromSeed)
│   ├── supabase/               # supabase.dart (client accessor)
│   ├── errors/                 # failures.dart (Either<Failure, T> types)
│   ├── utils/                  # drive_url.dart, relative_time.dart, result.dart
│   ├── constants/               # app_spacing.dart, icon_registry.dart (8 section icons)
│   └── widgets/                 # PrimaryButton, AppCard, ProgressBar, EmptyState,
│                                 #   ErrorState, InitialsAvatar, StatusBadge,
│                                 #   McqOptionCard, OfflineBanner
├── models/                     # Immutable DTOs w/ fromJson (freezed) for every
│                                 #   table/view in schema.sql
└── features/
    ├── auth/ home/ path/ sections/ books/ lesson/ quiz/ exam/ certificates/
    ├── achievements/ qa/ profile/ notifications/
    └── admin/{dashboard,sections,books,lessons,exam,banners,qa,stats}/
```

Each feature follows the same internal structure:

```
feature/
├── data/
│   └── <x>_repository.dart    # Wraps all Supabase calls; returns Either<Failure, T>
├── cubit/ (or bloc/)          # <X>Cubit + <X>State (or <X>Bloc + <X>Event + <X>State)
├── view/                       # Pages/screens
└── widgets/                    # Feature-specific widgets
```

**Planned build order (matches `plan.md` phases):** scaffold/infra → auth → student shell/discovery → book/lesson/Q&A → final exam/certificates/achievements → profile/notifications → admin core → admin authoring → hardening/white-label.

---

## State Management

- **Cubit** — all standard screens: Home, Path, Sections, Book Details, Profile, Notifications, all Admin screens, etc.
- **Bloc** — `exam` feature only: multiple events (answer selected, next/prev, tick, submit), timer-driven state, resume/auto-submit logic
- **Global cubits:** `AuthCubit` (session + role, drives routing), `ThemeCubit`, `ConnectivityCubit`

State classes: **4 explicit classes per feature**, not freezed unions — `<X>Initial`, `<X>Loading`, `<X>Loaded(data)` (+ `<X>Empty` where relevant), `<X>Error(message)`. All extend `Equatable`.

```dart
// lib/features/books/cubit/book_details_state.dart
abstract class BookDetailsState extends Equatable {
  const BookDetailsState();
  @override
  List<Object?> get props => [];
}

class BookDetailsInitial extends BookDetailsState {}
class BookDetailsLoading extends BookDetailsState {}
class BookDetailsLoaded extends BookDetailsState {
  final BookEntity book;
  final bool isEnrolled;
  const BookDetailsLoaded(this.book, this.isEnrolled);
  @override
  List<Object?> get props => [book, isEnrolled];
}
class BookDetailsError extends BookDetailsState {
  final String message;
  const BookDetailsError(this.message);
  @override
  List<Object?> get props => [message];
}
```

### Realtime vs Refetch

- **Realtime** Supabase channel subscriptions on exactly two surfaces: **student Notifications list** and **admin Q&A inbox**.
- **Everything else** = explicit refetch-after-mutation + pull-to-refresh. No global realtime.

---

## Key Patterns

### Repository Method Template

```dart
// lib/features/books/data/book_repository.dart
class BookRepository {
  final SupabaseClient _client;
  BookRepository(this._client);

  Future<Either<Failure, BookEntity>> getBook(String bookId) async {
    try {
      final response = await _client
          .from('books')
          .select()
          .eq('id', bookId)
          .single();
      return Right(BookEntity.fromJson(response));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
```

### Cubit Calls Repository — Never Supabase Directly

```dart
Future<void> loadBook(String bookId) async {
  emit(BookDetailsLoading());
  final result = await _bookRepository.getBook(bookId);
  result.fold(
    (failure) => emit(BookDetailsError(failure.message)),
    (book) => emit(BookDetailsLoaded(book, isEnrolled: false)),
  );
}
```

### DI Registration

```dart
// app/bloc_providers.dart
MultiRepositoryProvider(
  providers: [
    RepositoryProvider<BookRepository>(create: (_) => BookRepository(supabase)),
    RepositoryProvider<EnrollmentRepository>(create: (_) => EnrollmentRepository(supabase)),
    // ... one per feature
  ],
  child: MultiBlocProvider(
    providers: [
      BlocProvider<AuthCubit>(create: (ctx) => AuthCubit(ctx.read<AuthRepository>())),
      // ... global cubits only; feature cubits are provided per-route
    ],
    child: const SheikhyApp(),
  ),
)
```

### Connectivity Check — Required in Every Repository Method That Hits Supabase

```dart
final ConnectivityCubit _connectivity; // injected

Future<Either<Failure, T>?> _checkNetwork<T>() async {
  if (!_connectivity.state.isOffline) return null;
  return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
}
```

> Realtime channel subscriptions do **not** need a connectivity pre-check — Supabase handles reconnection automatically.

### Key Write Patterns (from `plan.md`)

- `lesson_progress`: **upsert on `(user_id, lesson_id)`** — sets `completed`, `last_position_seconds`, `completed_at`.
- `enrollments`: **insert with conflict-ignore** on `(user_id, book_id)` — idempotent (CC-19).
- `notification_reads`: **bulk insert** for "تحديد الكل كمقروء".
- **Final exam submission:** single `submit_final_exam` RPC call — no client-side attempt/certificate writes. This RPC is `SECURITY DEFINER` and handles grading, attempt-limit enforcement, and certificate issuance server-side.
- **Lesson save:** the 4 content tabs (video/audio/PDF/quiz) belong to ONE lesson record — a single sticky "حفظ الدرس" action saves all tab data in one Supabase call, regardless of which tab is active.
- Q&A: student `insert` only; admin `update` (answer + status) only.

### Correct Answers Must Never Reach the Client Pre-Grading (CC-18)

Lesson quiz and final exam question fetches **must** use the `_student` views (`lesson_quiz_questions_student`, `final_exam_questions_student`), which omit `correct_choice`. Never query the base tables from student-facing screens.

### Q&A Asker Anonymity (CC-22)

Student-facing Q&A screens **must** query `student_questions_public` (no `user_id` exposed). Only Admin screens query the base `student_questions` table directly.

### Google Drive URL Conversion

Audio and PDF links pasted by the admin (Drive share links) must be converted via `core/utils/drive_url.dart` to the direct-download format (`https://drive.google.com/uc?export=download&id=FILE_ID`) before use. Never pass a raw share link to a player/downloader.

### Audio: Download-Then-Play (never stream Drive audio)

Audio tab always downloads the file locally first (`dio`, with progress + cancel), checks for an existing local copy before re-downloading, and only then plays via `just_audio`. Never attempt direct streaming from a Drive URL.

---

## Backend Notes

- **`schema.sql` is authoritative and finalized** — do not add, rename, or restructure tables/columns without an explicit decision logged in `plan.md`.
- **Companion migration** (`supabase/migrations/0001_app_support.sql`) is additive-only, layered on top of the base schema. It adds: 3 student-safe views (hiding `correct_choice` / asker `user_id`), the `submit_final_exam` RPC, and the `grade_lesson_quiz` RPC. Always check this migration exists and has been run before building any feature that depends on it (exam, lesson quiz, Q&A).
- The `on_auth_user_created` trigger already exists in the live database — never create a duplicate; the client never inserts the `public.users` profile row itself.
- Only the Supabase **anon key** is used in the Flutter client. The `service_role` key is never referenced anywhere in `lib/`.

---

## Firestore Structure

Not applicable — this project uses **Supabase (PostgreSQL)**, not Firestore. See `docs/schema.sql` for the full table structure (15 tables) and `docs/Supabase_Setup_Guide.md` for how they were provisioned.

**Table naming:** `snake_case` plural — `books`, `lessons`, `final_exam_attempts`.
**Column naming:** `snake_case` — `full_name`, `created_at`, `is_featured`.
**Route naming:** `kebab-case` path segments — `/book-details/:id`, `/add-lesson`.

---

## Theming & Localization

- Two themes: **light** and **dark**, both supported (no default preference forced). Persisted in `SharedPreferences` key: `app_theme`.
- **Single locale: Arabic only** (`Locale('ar')`), full RTL. No English toggle in v1.
- Primary color and sheikh name are **white-label variables** read from `--dart-define` (`PRIMARY_COLOR`, `SHEIKH_NAME`) — never hardcoded. Reference design uses dark green + gold accent.
- Use `AppTheme.light(primaryColor:)` / `AppTheme.dark(primaryColor:)`, both built from `ColorScheme.fromSeed(seedColor: AppConfig.primaryColor)`.
- Font: Cairo (via `google_fonts`).
- Progress bar color convention: green = in-progress, gold = 100% complete.
- Status badge convention: green = published/completed/answered, gold/yellow = draft/in-review/pending.

---

## UX Requirements

Every async Supabase operation must:
1. Show a **loading indicator** — full-page spinner for page loads; disable button + show spinner during actions.
2. Show a **SnackBar** on success (green, 3s) or error (red, 4s), with an Arabic message.

Confirmation required via `AlertDialog` or `BottomSheet` before: enrolling in a book, submitting the final exam, deleting a book/section/lesson, logout.

Every list screen must handle an **empty state** with an icon, localized Arabic message, and action button where applicable (e.g., "لا توجد كتب بعد" → "تصفح الأقسام").

---

## GoRouter Auth & Role Guard

Root `/` redirects based on `AuthCubit` state:
- No session → `/login`
- Session + `role == student` → `/home`
- Session + `role == admin` → `/admin`

Student main screens (`/home`, `/path`, `/achievements`, `/profile`) are wrapped in a `ShellRoute` for the 4-item persistent bottom nav. Admin screens (`/admin`, `/admin/settings`) are wrapped in a separate `ShellRoute` for the 2-item admin bottom nav.

Deep links: `io.sheikhy.app://reset-callback` (password reset), email-confirmation callback.

---

## Error Handling

- Every Repository method wraps its body in `try/catch` and returns `Left(Failure)` on error.
- Failure subclasses: `ServerFailure`, `NetworkFailure`, `AuthFailure`, `PermissionFailure`, `ValidationFailure`, `EnrollmentRequiredFailure`, `AttemptsExhaustedFailure`, `NotEnrolledFailure`.
- Failure types must be **specific** — never catch a generic `Exception`.
- User-facing errors must be mapped to **localized Arabic strings** — never show a raw `PostgrestException` message.
- Log all errors with `Logger('<FeatureName>')` — e.g. `Logger('BookRepository')`.

---

## Tech Stack

| Package | Purpose |
|---|---|
| `supabase_flutter` | Backend: Auth, DB, Realtime — anon key only, RLS enforced |
| `flutter_bloc`, `bloc`, `equatable` | State management |
| `dartz` | `Either<Failure, T>` functional returns |
| `go_router` | Navigation with role-based auth guard |
| `youtube_player_iframe` | Video playback (Unlisted YouTube, mobile + future web) |
| `just_audio`, `audio_session`, `dio`, `path_provider` | Audio download-then-play |
| `pdfx` | In-app PDF viewing from Drive direct-download URL |
| `pdf`, `printing` | Client-side certificate PDF generation + share/save |
| `fl_chart` | Admin stats (enrollment trend, score visualization) |
| `flutter_heatmap_calendar` | Student achievements activity heatmap |
| `cached_network_image`, `image_picker` | Cover/banner images |
| `connectivity_plus` | Network connectivity detection |
| `shared_preferences` | Theme persistence, exam-resume state, resend cooldown timestamps |
| `intl` | Date/relative-time formatting |
| `url_launcher` | Opening external links (email app, live stream) |
| `carousel_slider` | Home banner carousel |
| `permission_handler` | Storage permission for audio downloads |
| `google_fonts` | Cairo font |
| `firebase_core`, `firebase_messaging` | Push notifications (optional sub-phase, topic-based) |
| `freezed`, `json_serializable` | Immutable model DTOs |

> Do not add packages without asking first.

---

## Naming Conventions

### Files

| Type | Pattern | Example |
|---|---|---|
| All Dart files | `snake_case.dart` | `book_repository.dart` |
| Test files | `<subject>_test.dart` | `book_repository_test.dart` |

### Classes

| Type | Pattern | Example |
|---|---|---|
| Model (DTO) | `<Name>Entity` | `BookEntity`, `LessonEntity` |
| Repository | `<Name>Repository` | `BookRepository`, `ExamRepository` |
| Cubit | `<Name>Cubit` | `BookDetailsCubit` |
| Bloc | `<Name>Bloc` | `ExamBloc` |
| State | `<Name>State` (4 explicit subclasses) | `BookDetailsState` → `Initial/Loading/Loaded/Error` |
| Event (Bloc) | `<Name>Event` | `ExamEvent` (`Started`, `AnswerSelected`, `Submitted`, ...) |
| Page / Screen | `<Name>Page` | `BookDetailsPage`, `LessonPage` |
| Reusable widget | Descriptive noun | `McqOptionCard`, `ProgressBar`, `InitialsAvatar` |
| Exception | `<Name>Exception` | `ServerException`, `NetworkException` |
| Failure | `<Name>Failure` | `NetworkFailure`, `EnrollmentRequiredFailure` |

### Variables & Methods

- `camelCase` for all local variables, parameters, and method names.
- `_camelCase` (leading underscore) for private fields and methods.
- `lowerCamelCase` for named constructors: `BookEntity.fromJson(...)`.
- Boolean variables/getters start with `is`, `has`, or `can`: `isEnrolled`, `hasAttemptsLeft`, `canSubmit`.

---

## Do

- Add a **file path comment** at the top of every code block.
- Use `const` constructors wherever possible.
- Register every repository in `app/bloc_providers.dart`.
- Always go through a Repository from a Cubit/Bloc — never call `Supabase.instance.client` directly from Presentation.
- Return `Either<Failure, T>` from every repository method.
- Use Arabic strings directly in UI code (single-locale app — no `.arb` files needed for v1).
- Handle grading and score calculations **server-side** in the `submit_final_exam` RPC — never trust or duplicate grading logic on the client.
- Use `equatable` for all entities and state classes.
- Close Supabase Realtime channel subscriptions in the Cubit's `close()` method.
- Use `ListView.builder` for all lists — never `Column` + `.map()` for variable-length data.
- Use pagination for any list that can grow large (books, lessons, questions).
- Always show a loading indicator for async operations that block the UI.
- Always use SnackBar to provide feedback on success or failure of every operation.
- Use `context.read<Cubit>()` to dispatch actions; `BlocBuilder`/`BlocSelector` only for rebuilding.
- Always check `mounted` before using `BuildContext` after any `await` in a widget.
- Use `context.read<RepositoryType>()` to resolve repositories in Cubits — never instantiate a repository manually inside a widget.
- Keep all entity fields `final` and use `copyWith` (via `freezed`) for updates.
- Write a **unit test** for every repository method covering the success path and every failure path.
- Use named parameters for any constructor with more than two parameters.
- Extract magic numbers and repeated string keys into named constants.
- Use `BlocSelector` instead of `BlocBuilder` when only one field of the state is needed.
- Always attach `.limit()` to any Supabase query that could return an unbounded result set.
- Use the `_student` views for any quiz/exam question fetch on the student side (CC-18).
- Use `student_questions_public` for any Q&A fetch on the student side (CC-22).
- Convert every Google Drive link through `drive_url.dart` before use.
- Check for an existing local audio file before downloading (CC-9/CC-10 alignment).
- Use `AppSpacing` constants for all padding and spacing — never raw pixel values inline.
- Use `EdgeInsetsDirectional` and `AlignmentDirectional` instead of left/right variants.
- Wrap every form page in `SingleChildScrollView` with `resizeToAvoidBottomInset: true`.

---

## Don't

- Don't use `print()` — use `Logger`.
- Don't use `setState` — BLoC/Cubit only.
- Don't catch a generic `Exception` — catch specific types (`PostgrestException`, `SocketException`, etc.).
- Don't use `dynamic` — always specify types.
- Don't call `Supabase.instance.client` directly from Presentation or Cubit/Bloc layers — always go through a Repository.
- Don't put business logic inside Cubits or the UI — keep grading/scoring/eligibility logic server-side (RPC) or in the Repository layer.
- Don't hardcode the sheikh's name or primary color — use `AppConfig`/`--dart-define`.
- Don't wrap large widget trees in `BlocBuilder` — wrap only the widget that changes.
- Don't ignore an `Either` return value — always call `.fold()` on it.
- Don't fetch `correct_choice` on any student-facing screen — use the `_student` views only.
- Don't expose `user_id` in any student-facing Q&A query — use `student_questions_public`.
- Don't stream audio directly from a Google Drive URL — always download-then-play.
- Don't write client-side final exam grading, attempt counting, or certificate issuance logic — always call `submit_final_exam`.
- Don't use `as` casts blindly — prefer `is` checks or safe casting patterns.
- Don't store sensitive data (the Supabase `service_role` key, credentials) anywhere in `lib/`.
- Don't navigate or show dialogs inside a Cubit/Bloc — emit a state and react to it in the UI layer.
- Don't create a new `TextEditingController` or `ScrollController` inside `build()` — declare in State and dispose in `dispose()`.
- Don't use `shrinkWrap: true` inside a `SingleChildScrollView` — it forces measuring all children at once.
- Don't ignore a Realtime `StreamSubscription` — cancel it in `Cubit.close()` / `Bloc.close()`.
- Don't hold a reference to `BuildContext` in a Cubit or any long-lived object.
- Don't add packages without asking first.
- Don't hardcode `fontSize` values — use `textTheme` styles only.
- Don't use `EdgeInsets.only(left/right)` or `Alignment.centerLeft/Right` — breaks RTL.
- Don't hardcode pixel widths or heights — use fractional sizing or `LayoutBuilder`.
- Don't redesign or rename anything in `schema.sql` — flag conflicts instead of guessing.

---

## Performance Rules

### Widget Rebuilds
- Use `BlocSelector` instead of `BlocBuilder` when only one field of the state is needed — rebuilds only when that field changes.
- Split large pages into smaller `StatelessWidget`s so Flutter can skip unchanged subtrees.
- Prefer `const` widgets at every level — a `const` subtree is never re-evaluated.
- Use `RepaintBoundary` around widgets that animate or update frequently (exam timer, charts).

### Lists & Scrolling
- Always use `ListView.builder` / `SliverList` with `itemCount`.
- Use `const` item widgets wherever possible so unchanged tiles are never rebuilt.
- Implement pagination for any collection that can grow (books, lessons, questions, notifications).
- Avoid `shrinkWrap: true` inside `SingleChildScrollView`.

### Supabase Queries
- Always attach `.limit()` to unbounded queries.
- Filter and sort in the query (`.eq()`, `.order()`), not in Dart after fetching.
- Use `.select('specific,columns')` projections when only a subset of fields is needed (e.g., list views).
- Prefer a single RPC call over multiple round-trips for multi-step operations (see `submit_final_exam`).

### Async & Compute
- Run heavy JSON parsing or sorting inside `compute()` for large datasets.
- Avoid `await` inside `build()` — trigger async work in Cubit/Bloc and react to emitted states.

### Memory
- Cancel Realtime `StreamSubscription`s in `Cubit.close()` / `Bloc.close()`.
- Dispose `AnimationController`, `TextEditingController`, and `ScrollController` in `State.dispose()`.
- Don't hold a reference to `BuildContext` in a Cubit or long-lived object.
- Clean up partially-downloaded audio files on cancel/error (CC-9) — never leave orphaned temp files.

## Responsive Rules

### Layout
- Never hardcode widths or heights — use `MediaQuery.sizeOf(context)`,
  `LayoutBuilder`, or fractional sizing.
- Use `Flexible` and `Expanded` inside `Row`/`Column` instead of fixed pixel widths.
- Minimum tappable area is 48×48 dp — wrap small icons in `SizedBox` or use `IconButton`.
- Use `SafeArea` on every top-level page widget — never assume screen insets are zero.

### Text & Fonts
- Never hardcode `fontSize` — use `Theme.of(context).textTheme` styles only
  (`titleLarge`, `bodyMedium`, etc.).
- All body and label text must respect system font scale (no `TextScaler.noScaling`
  except on purely decorative/icon text).

### Keyboard & Scroll
- Wrap every form page (sign up, add book, add lesson, ask question) in
  `SingleChildScrollView` + `resizeToAvoidBottomInset: true` so fields are never
  hidden behind the keyboard.
- Add `SizedBox(height: MediaQuery.viewInsetsOf(context).bottom)` at the bottom
  of scrollable forms as a keyboard-aware spacer.

### Spacing & Padding
- Define all spacing as named constants in `core/constants/app_spacing.dart`
  (e.g. `AppSpacing.sm = 8`, `AppSpacing.md = 16`, `AppSpacing.lg = 24`).
- Never write raw `EdgeInsets.all(16)` inline — always use `AppSpacing` constants.

### RTL (this app is RTL-only — no LTR fallback needed, but conventions still matter for consistency and any future web/English support)
- Never use `Alignment.centerLeft` / `centerRight` or `EdgeInsets.only(left/right)` —
  use `Alignment.centerStart` / `centerEnd` and `EdgeInsetsDirectional` instead.
- All icons that imply direction (arrows, chevrons, "next lesson" ›) must respect
  RTL automatically via `Directionality` — verify visually against `docs/screens/` mockups.
- Test every new screen against its matching mockup in both light and dark theme before marking it done.
