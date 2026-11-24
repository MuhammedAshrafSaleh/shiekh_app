// lib/core/cubit/view_mode_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BrowseViewMode { sections, levels }

/// Persists the student browse view-mode choice (sections vs levels) to
/// [SharedPreferences]. Device-local only — never written to the DB.
/// Mirrors [ThemeCubit].
class ViewModeCubit extends Cubit<BrowseViewMode> {
  static const _key = 'browse_view_mode';

  ViewModeCubit() : super(BrowseViewMode.sections);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    emit(
      saved == 'levels' ? BrowseViewMode.levels : BrowseViewMode.sections,
    );
  }

  Future<void> set(BrowseViewMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      mode == BrowseViewMode.levels ? 'levels' : 'sections',
    );
  }
}
