import 'dart:io';

import 'package:fantasy_color/utils/image_source.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isAssetPath recognizes bundle paths', () {
    expect(isAssetPath('assets/stickers/a.png'), isTrue);
    expect(isAssetPath('/tmp/packs/a.png'), isFalse);
  });

  test('missing local file is not available', () {
    expect(isLocalImageAvailable('/definitely/missing/sticker.png'), isFalse);
    expect(isLocalImageAvailable(''), isFalse);
    expect(isLocalImageAvailable('assets/stickers/a.png'), isTrue);
  });

  test('imageProviderFor falls back instead of FileImage on missing file', () {
    final provider = imageProviderFor('/definitely/missing/sticker.png');
    expect(provider, isA<MemoryImage>());
    expect(provider, same(transparentImageProvider));
  });

  test('loadImageBytes throws clearly when file is missing', () async {
    await expectLater(
      loadImageBytes('/definitely/missing/sticker.png'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Lokale Bilddatei fehlt'),
        ),
      ),
    );
  });

  test('isBenignImageLoadError covers Crashlytics FileImage cases', () {
    expect(
      isBenignImageLoadError(
        PathNotFoundException('/tmp/x.png', const OSError('', 2)),
      ),
      isTrue,
    );
    expect(
      isBenignImageLoadError(
        StateError('Bad state: Failed to load FileImage(/tmp/x.png)'),
      ),
      isTrue,
    );
    expect(isBenignImageLoadError(StateError('unrelated boom')), isFalse);
  });
}
