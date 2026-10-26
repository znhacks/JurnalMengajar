import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/screens/auth/splash_screen.dart';

void main() {
  testWidgets('splash mengikuti tema terang', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        ),
        home: const SplashScreen(),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(scaffold.backgroundColor, const Color(0xFFF8FAFC));
    expect(
      (provider.imageProvider as AssetImage).assetName,
      'assets/LogoJr.png',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 2300));
  });

  testWidgets('splash mengikuti tema gelap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
        ),
        home: const SplashScreen(),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(scaffold.backgroundColor, const Color(0xFF0F172A));
    expect(
      (provider.imageProvider as AssetImage).assetName,
      'assets/logoJurnalMengajarLogin.png',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 2300));
  });
}
