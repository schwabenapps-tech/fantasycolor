import 'package:fantasy_color/data/sticker_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bundle = [
    StickerEntry(id: 'sticker_01', assetPath: 'assets/stickers/a.png'),
    StickerEntry(id: 'sticker_02', assetPath: 'assets/stickers/b.png'),
  ];

  test('new remote stickers are prepended newest-first', () {
    final remote = [
      const StickerEntry(
        id: 'remote_pack_old',
        assetPath: '/tmp/old.png',
      ),
      const StickerEntry(
        id: 'remote_pack_new',
        assetPath: '/tmp/new.png',
      ),
    ];
    final merged = StickerCatalog.merge(
      bundle,
      remote,
      isNew: (_) => true,
      addedAt: (id) => id.endsWith('new')
          ? DateTime(2026, 11, 9)
          : DateTime(2026, 11, 1),
    );
    expect(merged.stickers.map((s) => s.id).toList(), [
      'remote_pack_new',
      'remote_pack_old',
      'sticker_01',
      'sticker_02',
    ]);
  });

  test('bundle duplicate by filename key is skipped', () {
    final remote = [
      const StickerEntry(
        id: 'remote_pack_a',
        assetPath: '/cache/a.png', // same normalize key as sticker_01
      ),
    ];
    final merged = StickerCatalog.merge(bundle, remote, isNew: (_) => true);
    expect(merged.stickers.map((s) => s.id), ['sticker_01', 'sticker_02']);
  });

  test('expired remote stickers go after bundle', () {
    final remote = [
      const StickerEntry(
        id: 'remote_pack_old',
        assetPath: '/tmp/old.png',
      ),
    ];
    final merged = StickerCatalog.merge(
      bundle,
      remote,
      isNew: (_) => false,
    );
    expect(merged.stickers.map((s) => s.id).toList(), [
      'sticker_01',
      'sticker_02',
      'remote_pack_old',
    ]);
  });
}
