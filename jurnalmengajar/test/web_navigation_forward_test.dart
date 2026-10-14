import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jurnalmengajar/widgets/web_navigation_shortcut_wrapper.dart';

GoRouter _createRouter() {
  return GoRouter(
    initialLocation: '/a',
    routes: [
      GoRoute(path: '/a', builder: (context, state) => const Text('Page A')),
      GoRoute(path: '/b', builder: (context, state) => const Text('Page B')),
      GoRoute(path: '/c', builder: (context, state) => const Text('Page C')),
    ],
  );
}

Future<void> _pumpWithWrapper(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (ctx, child) => WebNavigationShortcutWrapper(
        router: router,
        child: child ?? const SizedBox(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Real-time pause so the wrapper debounce (300ms, based on DateTime.now)
/// does not swallow the key. Must use runAsync: the test body runs in
/// FakeAsync where a plain Future.delayed never elapses.
Future<void> _settleDebounce(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 350)),
);

Future<void> _pressAltLeft(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

Future<void> _pressAltRight(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

void main() {
  group('WebNavigationShortcutWrapper forward navigation', () {
    testWidgets('back then forward returns to the departed page', (
      tester,
    ) async {
      final router = _createRouter();
      await _pumpWithWrapper(tester, router);
      expect(find.text('Page A'), findsOneWidget);

      router.push('/b');
      await tester.pumpAndSettle();
      expect(find.text('Page B'), findsOneWidget);

      await _settleDebounce(tester);
      await _pressAltLeft(tester);
      expect(find.text('Page A'), findsOneWidget);

      await _settleDebounce(tester);
      await _pressAltRight(tester);
      expect(find.text('Page B'), findsOneWidget);
    });

    testWidgets('forward with empty history does nothing', (tester) async {
      final router = _createRouter();
      await _pumpWithWrapper(tester, router);
      expect(find.text('Page A'), findsOneWidget);

      await _settleDebounce(tester);
      await _pressAltRight(tester);
      expect(find.text('Page A'), findsOneWidget);
    });

    testWidgets('fresh navigation clears forward history', (tester) async {
      final router = _createRouter();
      await _pumpWithWrapper(tester, router);

      router.push('/b');
      await tester.pumpAndSettle();

      await _settleDebounce(tester);
      await _pressAltLeft(tester);
      expect(find.text('Page A'), findsOneWidget);

      // New navigation instead of going forward.
      router.push('/c');
      await tester.pumpAndSettle();
      expect(find.text('Page C'), findsOneWidget);

      await _settleDebounce(tester);
      await _pressAltRight(tester);
      expect(find.text('Page C'), findsOneWidget);
      expect(find.text('Page B'), findsNothing);
    });
  });
}
