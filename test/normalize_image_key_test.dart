import 'package:fantasy_color/data/event_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeImageKey strips punctuation like upload normalize_name', () {
    expect(
      normalizeImageKey('ChatGPT-Bild_13._Okt._2026,_20_57_15.png'),
      'chatgpt_bild_13_okt_2026_20_57_15',
    );
    expect(
      normalizeImageKey('chibi_brueder_mit_leuchtenden_feenfluegeln.png'),
      'chibi_brueder_mit_leuchtenden_feenfluegeln',
    );
    expect(
      normalizeImageKey('assets/stickers/0c4e984a_7946_4fe1_be57_df9819b4e034.png'),
      '0c4e984a_7946_4fe1_be57_df9819b4e034',
    );
  });

  test('normalizeImageKey maps umlauts so NFC/NFD titles match', () {
    expect(
      normalizeImageKey('Chibi-Herzfee mit fröhlich geschlossenen Augen.png'),
      'chibi_herzfee_mit_frohlich_geschlossenen_augen',
    );
    // NFD: o + combining diaeresis
    expect(
      normalizeImageKey('Chibi-Herzfee mit fro\u0308hlich geschlossenen Augen.png'),
      'chibi_herzfee_mit_frohlich_geschlossenen_augen',
    );
  });
}

