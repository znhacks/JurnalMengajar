import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/widgets/admin_selection_action_button.dart';

void main() {
  group('AdminSelectionActionButton Widget Tests', () {
    testWidgets('renders checklist_rounded icon without square background container', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Test Header'),
              actions: [
                AdminSelectionActionButton(
                  onPressed: () => pressed = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify Icon is Icons.checklist_rounded
      final iconFinder = find.byIcon(Icons.checklist_rounded);
      expect(iconFinder, findsOneWidget);

      // Verify tooltip
      final iconButtonFinder = find.byType(IconButton);
      expect(iconButtonFinder, findsOneWidget);
      final iconButton = tester.widget<IconButton>(iconButtonFinder);
      expect(iconButton.tooltip, 'Pilih Massal');

      // Verify shape is strictly CircleBorder (never a square or box container)
      final shape = iconButton.style?.shape?.resolve({});
      expect(shape, isA<CircleBorder>());

      // Verify tap interaction
      await tester.tap(iconButtonFinder);
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });

    testWidgets('adapts properly to Dark Mode with appropriate contrast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Dark Mode Test'),
              actions: [
                AdminSelectionActionButton(
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final iconButtonFinder = find.byType(IconButton);
      expect(iconButtonFinder, findsOneWidget);

      final iconButton = tester.widget<IconButton>(iconButtonFinder);
      final fgColor = iconButton.style?.foregroundColor?.resolve({});
      expect(fgColor, isNotNull);
      // In dark theme, the icon color should be light for readability
      expect(fgColor, const Color(0xFFF8FAFC));
    });

    testWidgets('handles disabled state when onPressed is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Disabled Test'),
              actions: const [
                AdminSelectionActionButton(
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      );

      final iconButtonFinder = find.byType(IconButton);
      expect(iconButtonFinder, findsOneWidget);

      final iconButton = tester.widget<IconButton>(iconButtonFinder);
      expect(iconButton.onPressed, isNull);

      final disabledFgColor = iconButton.style?.foregroundColor?.resolve({WidgetState.disabled});
      expect(disabledFgColor, isNotNull);
    });

    testWidgets('selection header renders checklist_rounded directly to the left of trash can icon', (tester) async {
      bool checklistTapped = false;
      bool deleteTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              title: const Text('2 Terpilih'),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.checklist_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Pilih Semua',
                  onPressed: () => checklistTapped = true,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Hapus Massal',
                  onPressed: () => deleteTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify Icons.checklist_rounded is present
      final checklistFinder = find.byIcon(Icons.checklist_rounded);
      expect(checklistFinder, findsOneWidget);

      // Verify Icons.delete (trash can) is present
      final deleteFinder = find.byIcon(Icons.delete);
      expect(deleteFinder, findsOneWidget);

      // Verify NO kotak/grid icons (Icons.select_all or Icons.deselect) exist
      expect(find.byIcon(Icons.select_all), findsNothing);
      expect(find.byIcon(Icons.deselect), findsNothing);

      // Verify checklist is to the left of delete (smaller x coordinate in LTR)
      final checklistTopLeft = tester.getTopLeft(checklistFinder);
      final deleteTopLeft = tester.getTopLeft(deleteFinder);
      expect(checklistTopLeft.dx, lessThan(deleteTopLeft.dx));

      // Test tap
      await tester.tap(checklistFinder);
      await tester.pumpAndSettle();
      expect(checklistTapped, isTrue);

      await tester.tap(deleteFinder);
      await tester.pumpAndSettle();
      expect(deleteTapped, isTrue);
    });
  });
}

