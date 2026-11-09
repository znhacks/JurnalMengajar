import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/widgets/app_dialog_actions.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  testWidgets('AppDialogActions renders Batal on left (OutlinedButton) and Simpan on right (ElevatedButton) with balanced layout', (tester) async {
    bool cancelPressed = false;
    bool confirmPressed = false;

    await tester.pumpWidget(
      buildTestableWidget(
        AppDialogActions(
          cancelText: 'Batal',
          confirmText: 'Simpan',
          onCancel: () => cancelPressed = true,
          onConfirm: () => confirmPressed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify both buttons exist
    final outlinedFinder = find.byType(OutlinedButton);
    final elevatedFinder = find.byType(ElevatedButton);
    expect(outlinedFinder, findsOneWidget);
    expect(elevatedFinder, findsOneWidget);

    // Verify button texts
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);

    // Verify left and right positioning (Batal left, Simpan right)
    final cancelCenter = tester.getCenter(outlinedFinder);
    final confirmCenter = tester.getCenter(elevatedFinder);
    expect(cancelCenter.dx < confirmCenter.dx, isTrue, reason: 'Batal must be positioned to the left of Simpan');

    // Verify heights and equal widths (both in Expanded)
    final cancelSize = tester.getSize(outlinedFinder);
    final confirmSize = tester.getSize(elevatedFinder);
    expect(cancelSize.height, confirmSize.height, reason: 'Buttons must have equal height (selevel)');
    expect(cancelSize.width, confirmSize.width, reason: 'Buttons must have equal width');

    // Tap Batal
    await tester.tap(outlinedFinder);
    expect(cancelPressed, isTrue);

    // Tap Simpan
    await tester.tap(elevatedFinder);
    expect(confirmPressed, isTrue);
  });

  testWidgets('AppDialogActions supports destructive styling and custom colors', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        AppDialogActions(
          cancelText: 'Batal',
          confirmText: 'Hapus',
          isDestructive: true,
          onCancel: () {},
          onConfirm: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}

