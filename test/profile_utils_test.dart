import 'package:flutter_test/flutter_test.dart';
import 'package:diplomka/ProfileUtils.dart';

void main() {
  group('ProfileUtils.parseInt', () {
    test('int', () {
      expect(ProfileUtils.parseInt(5), 5);
    });

    test('double', () {
      expect(ProfileUtils.parseInt(5.8), 5);
    });

    test('string int', () {
      expect(ProfileUtils.parseInt("10"), 10);
    });

    test('string double', () {
      expect(ProfileUtils.parseInt("10.5"), 10);
    });

    test('null', () {
      expect(ProfileUtils.parseInt(null), 0);
    });
  });

  group('ProfileUtils.parseDouble', () {
    test('int', () {
      expect(ProfileUtils.parseDouble(5), 5.0);
    });

    test('string', () {
      expect(ProfileUtils.parseDouble("5.5"), 5.5);
    });

    test('invalid', () {
      expect(ProfileUtils.parseDouble("abc"), 0.0);
    });
  });

  group('XP logic', () {
    test('xpMinForLevel', () {
      expect(ProfileUtils.xpMinForLevel(1), 0);
      expect(ProfileUtils.xpMinForLevel(2), 100);
      expect(ProfileUtils.xpMinForLevel(3), 400);
    });

    test('xpMaxForLevel', () {
      expect(ProfileUtils.xpMaxForLevel(1), 100);
      expect(ProfileUtils.xpMaxForLevel(2), 400);
    });

    test('progress', () {
      final progress = ProfileUtils.xpProgressPercent(150, 2);
      expect(progress, greaterThan(0));
      expect(progress, lessThan(1));
    });

    test('xpToNextLevel', () {
      expect(ProfileUtils.xpToNextLevel(150, 2), 250);
    });
  });

  group('formatDuration', () {
    test('seconds', () {
      expect(ProfileUtils.formatDuration(30), "30с");
    });

    test('minutes', () {
      expect(ProfileUtils.formatDuration(90), "1м 30с");
    });

    test('hours', () {
      expect(ProfileUtils.formatDuration(3700), "1ч 1м");
    });
  });

  group('formatIso', () {
    test('valid date', () {
      final res = ProfileUtils.formatIso("2025-01-01T10:05:00Z");
      expect(res.contains("2025"), true);
    });

    test('null', () {
      expect(ProfileUtils.formatIso(null), "-");
    });
  });

  group('formatPretty', () {
    test('invalid', () {
      expect(ProfileUtils.formatPretty("invalid"), "invalid");
    });

    test('null', () {
      expect(ProfileUtils.formatPretty(null), "-");
    });
  });
}