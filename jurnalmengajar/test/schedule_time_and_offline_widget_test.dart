import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/services/connectivity_service.dart';
import 'package:jurnalmengajar/core/utils/helper.dart';
import 'package:jurnalmengajar/widgets/offline_indicator_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Format Jam Pelajaran Jadwal (Tidak Bertumpuk & Tidak Terpotong)', () {
    test(
      'Format jam pelajaran bersih dalam 1 tanda kurung tunggal (tanpa kurung bersarang)',
      () {
        // Skenario 1: Sekolah WIB, Guru domisili WIB (sama)
        final sameTz = AppHelper.formatScheduleTimeRange(
          hrStart: '09:50',
          hrEnd: '11:50',
          schoolTz: 'WIB',
          userTz: 'WIB',
        );
        final labelSame = 'Jam Ke-5-7 ($sameTz)';
        expect(labelSame, 'Jam Ke-5-7 (09:50 - 11:50 WIB)');
        // Memastikan tidak ada kurung bersarang
        expect(labelSame.contains('(('), isFalse);
        expect(labelSame.contains('))'), isFalse);
        expect(labelSame.contains('sekolah'), isFalse);

        // Skenario 2: Sekolah WIB, Guru domisili WITA (Bali/Lombok/Sulawesi)
        final witaTz = AppHelper.formatScheduleTimeRange(
          hrStart: '09:50',
          hrEnd: '11:50',
          schoolTz: 'WIB',
          userTz: 'WITA',
        );
        final labelWita = 'Jam Ke-5-7 ($witaTz)';
        // Jam 09:50 WIB terkonversi tepat 1 jam ke depan menjadi 10:50 WITA
        expect(labelWita, 'Jam Ke-5-7 (10:50 - 12:50 WITA)');
        // Memastikan bebas dari kurung ganda bersarang dan teks berlebih
        expect(labelWita.contains('(('), isFalse);
        expect(labelWita.contains('))'), isFalse);
        expect(labelWita.contains('sekolah'), isFalse);

        // Skenario 3: Sekolah WIB, Guru domisili WIT (Papua/Maluku)
        final witTz = AppHelper.formatScheduleTimeRange(
          hrStart: '09:50',
          hrEnd: '11:50',
          schoolTz: 'WIB',
          userTz: 'WIT',
        );
        final labelWit = 'Jam Ke-5-7 ($witTz)';
        // Jam 09:50 WIB terkonversi 2 jam ke depan menjadi 11:50 WIT
        expect(labelWit, 'Jam Ke-5-7 (11:50 - 13:50 WIT)');
        expect(labelWit.contains('(('), isFalse);
        expect(labelWit.contains('))'), isFalse);
      },
    );
  });

  group('2. Banner Status & Pop-up Peringatan Otomatis Saat Offline', () {
    final connectivity = ConnectivityService.instance;

    setUp(() {
      connectivity.cancelTimersForTest();
      connectivity.reportOnline();
    });

    tearDown(() {
      connectivity.cancelTimersForTest();
    });

    testWidgets('Tampilan banner offline dan pop-up peringatan berfungsi', (
      tester,
    ) async {
      connectivity.cancelTimersForTest();
      connectivity.reportOnline();

      // Render aplikasi yang dibungkus OfflineIndicatorWrapper
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => const MaterialApp(
            home: Scaffold(
              body: OfflineIndicatorWrapper(
                child: Center(child: Text('Konten Halaman Aplikasi')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Saat online: Banner offline tidak boleh muncul, hanya konten utama
      expect(find.text('Konten Halaman Aplikasi'), findsOneWidget);
      expect(find.textContaining('Mode Offline'), findsNothing);
      expect(find.text('Koneksi Terputus'), findsNothing);

      // Simulasi: Perangkat kehilangan koneksi internet (masuk mode offline)
      connectivity.reportOffline();
      await tester.pump();
      await tester.pumpAndSettle();

      // 1. Verifikasi Banner Peringatan di atas layar muncul
      expect(find.textContaining('Mode Offline'), findsOneWidget);
      expect(
        find.text('Mode Offline • Aplikasi mungkin tidak berjalan optimal'),
        findsOneWidget,
      );
      expect(find.text('Coba Lagi'), findsOneWidget);

      // 2. Verifikasi Pop-up Dialog muncul di layar
      expect(find.text('Koneksi Terputus'), findsOneWidget);
      expect(
        find.textContaining(
          'Perangkat Anda saat ini tidak terhubung ke internet',
        ),
        findsOneWidget,
      );
      expect(find.text('Mengerti'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      final cancelCenter = tester.getCenter(find.text('Mengerti'));
      final confirmCenter = tester.getCenter(find.text('Coba Lagi'));
      expect(
        cancelCenter.dx < confirmCenter.dx,
        isTrue,
        reason: 'Mengerti harus di kiri, Coba Lagi di kanan',
      );
      expect(
        (cancelCenter.dy - confirmCenter.dy).abs() < 5.0,
        isTrue,
        reason: 'Harus sejajar horizontal',
      );

      // Tutup dialog dengan menekan tombol 'Mengerti'
      await tester.tap(find.text('Mengerti'));
      await tester.pumpAndSettle();
      expect(find.text('Koneksi Terputus'), findsNothing);

      // Banner tetap standby di atas layar selama masih offline
      expect(find.textContaining('Mode Offline'), findsOneWidget);

      // Simulasi: Koneksi internet kembali pulih (online)
      connectivity.reportOnline();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifikasi Banner Hijau 'Koneksi Pulih' muncul
      expect(find.text('Koneksi Pulih • Anda kembali online'), findsOneWidget);

      // Selesaikan durasi 3 detik banner pulih
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      connectivity.cancelTimersForTest();
    });
  });
}
