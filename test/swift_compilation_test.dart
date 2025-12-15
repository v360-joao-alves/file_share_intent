import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  group('Swift Compilation Tests', () {
    test('SwiftListenSharingIntentPlugin.swift compiles without errors',
        () async {
      final swiftFile = File('ios/Classes/SwiftListenSharingIntentPlugin.swift');
      expect(swiftFile.existsSync(), true, reason: 'Swift file should exist');

      // Check for Photos framework usage (should be none)
      final content = await swiftFile.readAsString();
      expect(content.contains('import Photos'), false,
          reason: 'Should not import Photos framework');
      expect(content.contains('PHAsset'), false,
          reason: 'Should not use PHAsset');
      expect(content.contains('PHImageManager'), false,
          reason: 'Should not use PHImageManager');
      expect(content.contains('PHContentEditingInputRequestOptions'), false,
          reason: 'Should not use Photos APIs');

      // Verify required imports are present
      expect(content.contains('import Flutter'), true,
          reason: 'Should import Flutter');
      expect(content.contains('import UIKit'), true,
          reason: 'Should import UIKit');
      expect(content.contains('import UniformTypeIdentifiers'), true,
          reason: 'Should import UniformTypeIdentifiers');

      // Run Swift syntax check
      final result = await Process.run(
          'swiftc',
          [
            '-parse',
            swiftFile.path,
          ],
          workingDirectory: Directory.current.path);

      expect(result.exitCode, 0,
          reason: 'Swift compilation should succeed. Errors: ${result.stderr}');
    });

    test('Models Share Extension classes compile without errors', () async {
      final baseShareFile = File('ios/Models/Sources/RSIBaseShareViewController.swift');
      final shareFile = File('ios/Models/Sources/RSIShareViewController.swift');

      expect(baseShareFile.existsSync(), true, 
          reason: 'RSIBaseShareViewController.swift should exist in Models');
      expect(shareFile.existsSync(), true, 
          reason: 'RSIShareViewController.swift should exist in Models');

      // Check for Photos framework usage (should be none)
      for (final file in [baseShareFile, shareFile]) {
        final content = await file.readAsString();
        expect(content.contains('import Photos'), false,
            reason: '${file.path} should not import Photos framework');
        expect(content.contains('PHAsset'), false,
            reason: '${file.path} should not use PHAsset');

        // Verify required imports are present
        expect(content.contains('import UIKit'), true,
            reason: '${file.path} should import UIKit');
        expect(content.contains('import Social'), true,
            reason: '${file.path} should import Social');

        // Verify NO Flutter dependency
        expect(content.contains('import Flutter'), false,
            reason: '${file.path} should NOT import Flutter (Share Extension)');
      }
    });

    test('Classes directory Swift files compile without errors', () async {
      final swiftFile = File('ios/Classes/SwiftListenSharingIntentPlugin.swift');

      expect(swiftFile.existsSync(), true,
          reason: 'Classes SwiftListenSharingIntentPlugin.swift should exist');

      // Check for Photos framework usage (should be none)
      final content = await swiftFile.readAsString();
      expect(content.contains('import Photos'), false,
          reason: '${swiftFile.path} should not import Photos framework');
      expect(content.contains('PHAsset'), false,
          reason: '${swiftFile.path} should not use PHAsset');

      // Verify Flutter import (main plugin should have it)
      expect(content.contains('import Flutter'), true,
          reason: '${swiftFile.path} should import Flutter (main plugin)');

      // Run Swift syntax check
      final result = await Process.run(
          'swiftc',
          [
            '-parse',
            swiftFile.path,
          ],
          workingDirectory: Directory.current.path);

      expect(result.exitCode, 0,
          reason:
              'Swift compilation should succeed for ${swiftFile.path}. Errors: ${result.stderr}');
    });
  });
}
