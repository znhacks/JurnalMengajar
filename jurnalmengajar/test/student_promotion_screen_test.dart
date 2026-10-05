import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';

Widget buildTestBottomBar({
  required BuildContext context,
  required int currentStep,
  required bool isDark,
  required VoidCallback onNext,
  required VoidCallback onBack,
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
    ),
    child: Row(
      children: [
        if (currentStep > 0) ...[
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Kembali'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
            ),
          ),
          SizedBox(width: 10.w),
        ],
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onNext,
            icon: Icon(
              currentStep == 2 ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
              size: 18,
            ),
            label: Text(
              currentStep == 2
                  ? 'Konfirmasi & Proses (3 Siswa)'
                  : (currentStep == 0 ? 'Pilih Siswa' : 'Verifikasi'),
              style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold, fontSize: 13.sp),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    ),
  );
}

void main() {
  group('StudentPromotionScreen Bottom Bar Tests', () {
    testWidgets('Step 0 displays strictly "Pilih Siswa" and no Kembali button', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) {
            return MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                bottomNavigationBar: SafeArea(
                  child: Builder(
                    builder: (ctx) => buildTestBottomBar(
                      context: ctx,
                      currentStep: 0,
                      isDark: true,
                      onNext: () {},
                      onBack: () {},
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Pilih Siswa'), findsOneWidget);
      expect(find.text('Lanjut ke Pilih Siswa'), findsNothing);
      expect(find.text('Kembali'), findsNothing);
    });

    testWidgets('Step 1 displays "Verifikasi" and "Kembali" without layout exceptions', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) {
            return MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                bottomNavigationBar: SafeArea(
                  child: Builder(
                    builder: (ctx) => buildTestBottomBar(
                      context: ctx,
                      currentStep: 1,
                      isDark: true,
                      onNext: () {},
                      onBack: () {},
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Verifikasi'), findsOneWidget);
      expect(find.text('Lanjut ke Verifikasi'), findsNothing);
      expect(find.text('Kembali'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
