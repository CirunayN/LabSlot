import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/supabase_config.dart';
import 'core/providers/labslot_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/labslot_shell.dart';
import 'features/auth/presentation/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initializeIfConfigured();
  runApp(
    const ProviderScope(
      child: LabSlotApp(),
    ),
  );
}

class LabSlotApp extends ConsumerWidget {
  const LabSlotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(
      labSlotProvider.select((state) => state.currentUser),
    );

    return MaterialApp(
      title: 'LabSlot – Campus Computer Lab & PC Station Booking System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: currentUser == null ? const LoginScreen() : const LabSlotShell(),
    );
  }
}
