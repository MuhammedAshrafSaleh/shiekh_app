// lib/features/notifications/cubit/connectivity_cubit.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectivityState {
  final bool isOffline;
  const ConnectivityState({required this.isOffline});
}

class ConnectivityCubit extends Cubit<ConnectivityState> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  ConnectivityCubit()
      : super(const ConnectivityState(isOffline: false)) {
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    emit(ConnectivityState(isOffline: offline));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
