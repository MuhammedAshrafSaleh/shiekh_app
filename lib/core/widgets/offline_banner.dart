// lib/core/widgets/offline_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/app_spacing.dart';
import '../../features/notifications/cubit/connectivity_cubit.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      buildWhen: (prev, curr) => prev.isOffline != curr.isOffline,
      builder: (context, state) {
        if (!state.isOffline) return const SizedBox.shrink();
        return ColoredBox(
          color: Colors.orange.shade700,
          child: const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'أنت غير متصل بالإنترنت',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
