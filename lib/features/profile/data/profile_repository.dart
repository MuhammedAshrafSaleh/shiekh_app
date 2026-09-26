class ProfileStats {
  final String fullName;
  final String email;
  final int enrolledBooks;
  final int completedLessons;
  final int certificates;

  const ProfileStats({
    required this.fullName,
    required this.email,
    required this.enrolledBooks,
    required this.completedLessons,
    required this.certificates,
  });
}

class ProfileRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('ProfileRepository');

  ProfileRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, ProfileStats>> getProfileStats() async {
    final networkError = _checkNetwork<ProfileStats>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final userFuture = _client
          .from('users')
          .select('full_name, email')
          .eq('id', userId)