// lib/features/admin/sections/view/admin_sections_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/icon_registry.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/section_entity.dart';
import '../cubit/admin_sections_cubit.dart';
import '../cubit/admin_sections_state.dart';

class AdminSectionsPage extends StatelessWidget {
  const AdminSectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminSectionsCubit, AdminSectionsState>(
      listener: (context, state) {
        if (state is AdminSectionsError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
          // Reload after error shown to restore list
          if (state.message.contains('حذف')) {
            context.read<AdminSectionsCubit>().load();
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('الأقسام العلمية'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<AdminSectionsCubit>().load(),
              ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.startFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await context.push('/admin/sections/new');
              if (context.mounted) {
                context.read<AdminSectionsCubit>().load();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('قسم جديد'),
          ),
          body: switch (state) {
            AdminSectionsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            AdminSectionsError() => ErrorState(
                message: state.message,
                onRetry: () => context.read<AdminSectionsCubit>().load(),