import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase Repositories
import 'repositories/supabase_auth_repository.dart';
import 'repositories/supabase_period_repository.dart';
import 'repositories/supabase_subject_repository.dart';
import 'repositories/supabase_hour_repository.dart';
import 'repositories/supabase_class_repository.dart';
import 'repositories/supabase_teacher_repository.dart';
import 'repositories/supabase_schedule_repository.dart';
import 'repositories/supabase_journal_repository.dart';
import 'repositories/supabase_settings_repository.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/master_data_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/journal_provider.dart';
import 'providers/settings_provider.dart';

// Router & Theme
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Indonesian date formatting for intl
  await initializeDateFormatting('id_ID', null);

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://egcxjuudphnbjwqhhbra.supabase.co',
    publishableKey: 'sb_publishable_8VGYplCO-QO1kTLhhEfJKw_On4QCQ4u',
  );

  final supabaseClient = Supabase.instance.client;

  // Instantiating Supabase repositories
  final authRepo = SupabaseAuthRepository(supabaseClient);
  final periodRepo = SupabasePeriodRepository(supabaseClient);
  final subjectRepo = SupabaseSubjectRepository(supabaseClient);
  final hourRepo = SupabaseHourRepository(supabaseClient);
  final classRepo = SupabaseClassRepository(supabaseClient);
  final teacherRepo = SupabaseTeacherRepository(supabaseClient);
  final scheduleRepo = SupabaseScheduleRepository(supabaseClient);
  final journalRepo = SupabaseJournalRepository(supabaseClient);
  final settingsRepo = SupabaseSettingsRepository(supabaseClient);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository: authRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => MasterDataProvider(
            periodRepository: periodRepo,
            subjectRepository: subjectRepo,
            hourRepository: hourRepo,
            classRepository: classRepo,
            teacherRepository: teacherRepo,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ScheduleProvider(scheduleRepository: scheduleRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => JournalProvider(journalRepository: journalRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(settingsRepository: settingsRepo),
        ),
      ],
      child: const JurnalMengajarApp(),
    ),
  );
}

class JurnalMengajarApp extends StatelessWidget {
  const JurnalMengajarApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap with ScreenUtilInit for fully responsive UI sizes across different screens
    return ScreenUtilInit(
      designSize: const Size(360, 690), // Standard layout design base
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Jurnal Mengajar',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          // Injecting GoRouter table
          routerConfig: AppRouter.router(context),
        );
      },
    );
  }
}

//tes
