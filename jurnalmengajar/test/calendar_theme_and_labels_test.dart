import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';

void main() {
  group('Calendar & DatePicker Theme Tests', () {
    testWidgets('AppTheme lightTheme configures datePickerTheme properly', (tester) async {
      final theme = AppTheme.lightTheme;
      final datePickerTheme = theme.datePickerTheme;

      expect(datePickerTheme, isNotNull);
      expect(datePickerTheme.backgroundColor, equals(AppTheme.surfaceColor));
      expect(datePickerTheme.headerBackgroundColor, equals(AppTheme.primaryColor));
      expect(datePickerTheme.headerForegroundColor, equals(Colors.white));
      expect(datePickerTheme.rangePickerBackgroundColor, equals(AppTheme.surfaceColor));
    });

    testWidgets('AppTheme darkTheme configures datePickerTheme with slate dark palette', (tester) async {
      final theme = AppTheme.darkTheme;
      final datePickerTheme = theme.datePickerTheme;

      expect(datePickerTheme, isNotNull);
      // Dark slate background (Slate 800)
      expect(datePickerTheme.backgroundColor, equals(const Color(0xFF1E293B)));
      expect(datePickerTheme.surfaceTintColor, equals(Colors.transparent));
      expect(datePickerTheme.headerBackgroundColor, equals(const Color(0xFF1E293B)));
      expect(datePickerTheme.headerForegroundColor, equals(const Color(0xFFF8FAFC)));
      expect(datePickerTheme.rangePickerBackgroundColor, equals(const Color(0xFF1E293B)));
      expect(datePickerTheme.dividerColor, equals(const Color(0xFF334155)));
    });
  });
}
