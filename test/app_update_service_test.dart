import 'package:fantasy_color/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUpdateService.compareVersions', () {
    test('detects older patch', () {
      expect(AppUpdateService.compareVersions('1.1.0', '1.1.1'), lessThan(0));
    });

    test('detects older minor', () {
      expect(AppUpdateService.compareVersions('1.1.0', '1.2.0'), lessThan(0));
    });

    test('equal versions', () {
      expect(AppUpdateService.compareVersions('1.1.0', '1.1.0'), 0);
    });

    test('newer than min is allowed', () {
      expect(AppUpdateService.compareVersions('1.2.0', '1.1.0'), greaterThan(0));
    });

    test('strips build suffix', () {
      expect(AppUpdateService.compareVersions('1.1.0+6', '1.1.0'), 0);
      expect(AppUpdateService.compareVersions('1.1.0+6', '1.2.0'), lessThan(0));
    });

    test('short versions pad with zeros', () {
      expect(AppUpdateService.compareVersions('1.1', '1.1.0'), 0);
      expect(AppUpdateService.compareVersions('1.0', '1.1.0'), lessThan(0));
    });
  });

  group('version string parsing', () {
    test('accepts string and number', () {
      expect(AppUpdateService.asVersionStringForTest('1.2.0'), '1.2.0');
      expect(AppUpdateService.asVersionStringForTest(1.2), '1.2');
      expect(AppUpdateService.asVersionStringForTest(2), '2');
      expect(AppUpdateService.asVersionStringForTest(''), isNull);
      expect(AppUpdateService.asVersionStringForTest(null), isNull);
    });
  });
}
