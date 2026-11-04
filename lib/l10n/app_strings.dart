import 'package:flutter/widgets.dart';

/// Leichte i18n-Schicht (Geräte-Sprache). EN-Fallback.
///
/// Sprachen: en, de, es, fr, pt, it, nl, pl, tr
class AppStrings {
  AppStrings._(this._m);

  final Map<String, String> _m;

  static const supported = <String>[
    'en',
    'de',
    'es',
    'fr',
    'pt',
    'it',
    'nl',
    'pl',
    'tr',
  ];

  static AppStrings of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return AppStrings._(_tables[code] ?? _tables['en']!);
  }

  String _t(String key) => _m[key] ?? _tables['en']![key] ?? key;

  String get muted => _t('muted');
  String get playing => _t('playing');
  String get music => _t('music');
  String get contactSupport => _t('contactSupport');
  String get contactSupportSub => _t('contactSupportSub');
  String get sendFeedback => _t('sendFeedback');
  String get sendFeedbackSub => _t('sendFeedbackSub');
  String get rateApp => _t('rateApp');
  String get rateAppSub => _t('rateAppSub');
  String get resetStickers => _t('resetStickers');
  String get resetStickersSub => _t('resetStickersSub');
  String get originalArtwork => _t('originalArtwork');
  String get originalArtworkSub => _t('originalArtworkSub');
  String get privacy => _t('privacy');
  String get privacySub => _t('privacySub');
  String get adPrivacy => _t('adPrivacy');
  String get adPrivacySubAvailable => _t('adPrivacySubAvailable');
  String get adPrivacySubUnavailable => _t('adPrivacySubUnavailable');
  String get terms => _t('terms');
  String get termsSub => _t('termsSub');
  String get resetStickersTitle => _t('resetStickersTitle');
  String get resetStickersBody => _t('resetStickersBody');
  String get cancel => _t('cancel');
  String get reset => _t('reset');
  String get stickersReset => _t('stickersReset');
  String get savedToPhotos => _t('savedToPhotos');
  String get saveToPhotos => _t('saveToPhotos');
  String get done => _t('done');
  String get colorMoreForDone => _t('colorMoreForDone');
  String get colorBeforeSave => _t('colorBeforeSave');
  String get wonderful => _t('wonderful');
  String get levelComplete => _t('levelComplete');
  String get photos => _t('photos');
  String get asPuzzle => _t('asPuzzle');
  String get couldNotLoadImage => _t('couldNotLoadImage');
  String get pickAGift => _t('pickAGift');
  String get eachBoxDifferent => _t('eachBoxDifferent');
  String get newSticker => _t('newSticker');
  String get dailySurprise => _t('dailySurprise');
  String get pickBoxToday => _t('pickBoxToday');
  String get dailyReward => _t('dailyReward');
  String get stickerAlbum => _t('stickerAlbum');
  String get stickerRulesBody => _t('stickerRulesBody');
  String get settings => _t('settings');
  String get welcomeTitle => _t('welcomeTitle');
  String get welcomeBody => _t('welcomeBody');
  String get letsGo => _t('letsGo');
  String get updateRequired => _t('updateRequired');
  String get updateNow => _t('updateNow');
  String get forceUpdateMessage => _t('forceUpdateMessage');
  String get home => _t('home');
  String get color => _t('color');
  String get puzzle => _t('puzzle');
  String get print => _t('print');
  String get favorites => _t('favorites');
  String get newItems => _t('newItems');
  String get newColor => _t('newColor');
  String get newPuzzle => _t('newPuzzle');
  String get lastEvent => _t('lastEvent');
  String get unlockWithAd => _t('unlockWithAd');
  String get recentlyUsed => _t('recentlyUsed');
  String get recentlyUsedEmpty => _t('recentlyUsedEmpty');
  String get notifyTitle => _t('notifyTitle');
  String get notifyBody => _t('notifyBody');
  String get notifyStreakTitle => _t('notifyStreakTitle');
  String get notifyStreakBody => _t('notifyStreakBody');
  String get streakQuestTitle => _t('streakQuestTitle');
  String get streakQuestTask => _t('streakQuestTask');
  String get streakQuestDone => _t('streakQuestDone');
  String get streakQuestTodo => _t('streakQuestTodo');
  String get streakQuestHint => _t('streakQuestHint');
  String get streakQuestClose => _t('streakQuestClose');
  String get artworkInfoBody => _t('artworkInfoBody');
  String get feedbackHint => _t('feedbackHint');
  String get send => _t('send');

  String streakSemantics(int n) =>
      _t('streakSemantics').replaceAll('{n}', '$n');

  String streakDays(int n) => _t('streakDays').replaceAll('{n}', '$n');

  String versionLabel(String v) =>
      _t('versionLabel').replaceAll('{v}', v);

  static const _tables = <String, Map<String, String>>{
    'en': _en,
    'de': _de,
    'es': _es,
    'fr': _fr,
    'pt': _pt,
    'it': _it,
    'nl': _nl,
    'pl': _pl,
    'tr': _tr,
  };
}

const _en = {
  'muted': 'Muted',
  'playing': 'Playing',
  'music': 'Music',
  'contactSupport': 'Contact support',
  'contactSupportSub': 'Report an issue and get help',
  'sendFeedback': 'Send feedback',
  'sendFeedbackSub': 'Share ideas or report a problem',
  'rateApp': 'Rate Fairy Fantasy Color',
  'rateAppSub': 'Open the store page',
  'resetStickers': 'Reset sticker album',
  'resetStickersSub': 'Clear collected stickers and the daily gift',
  'originalArtwork': 'Original artwork',
  'originalArtworkSub':
      'All images in Fairy Fantasy Color are original creations',
  'privacy': 'Privacy',
  'privacySub': 'How Fairy Fantasy Color handles your data',
  'adPrivacy': 'Ad privacy choices',
  'adPrivacySubAvailable': 'Review or change ad privacy settings',
  'adPrivacySubUnavailable':
      'Open privacy choices when available on your device',
  'terms': 'Terms of Use',
  'termsSub': 'Rules for using Fairy Fantasy Color',
  'resetStickersTitle': 'Reset sticker album?',
  'resetStickersBody':
      'All collected stickers and today’s daily gift will be cleared. This cannot be undone.',
  'cancel': 'Cancel',
  'reset': 'Reset',
  'stickersReset': 'Sticker album reset',
  'savedToPhotos': 'Saved to Photos!',
  'saveToPhotos': 'Save to Photos',
  'done': 'Done',
  'colorMoreForDone': 'Color a bit more to finish and earn a sticker!',
  'colorBeforeSave': 'Color a little first before saving.',
  'wonderful': 'Wonderful!',
  'levelComplete': 'Level complete',
  'photos': 'Photos',
  'asPuzzle': 'As puzzle',
  'couldNotLoadImage': 'Could not load image',
  'pickAGift': 'Pick a gift!',
  'eachBoxDifferent': 'Each box holds a different sticker',
  'newSticker': 'New sticker!',
  'dailySurprise': 'Daily surprise!',
  'pickBoxToday': 'Pick a box for today’s reward',
  'dailyReward': 'Daily reward!',
  'stickerAlbum': 'Sticker album',
  'stickerRulesBody':
      '• Finish a coloring page (about 90% painted) to earn a sticker — once per picture until you reset it.\n'
      '• Solve a puzzle on Pro difficulty to earn a sticker — once per puzzle.\n'
      '• Easy and Medium puzzles do not give stickers.\n'
      '• Each day you can pick a daily surprise gift box.\n'
      '• Every sticker unlocks only once — no duplicates.\n'
      '• Collect them all to download the free sticker pack.',
  'settings': 'Settings',
  'welcomeTitle': 'Welcome, little\nadventurer!',
  'welcomeBody':
      'A fairy world awaits —\ncolor · puzzle · explore\nmagic at your own pace.',
  'letsGo': "Let's go!",
  'updateRequired': 'Update required',
  'updateNow': 'Update now',
  'forceUpdateMessage':
      'A new version of Fairy Fantasy Color is required.\nPlease update in the store to continue playing.',
  'home': 'Home',
  'color': 'Color',
  'puzzle': 'Puzzle',
  'print': 'Print',
  'favorites': 'Favorites',
  'newItems': 'New',
  'newColor': 'New color',
  'newPuzzle': 'New puzzle',
  'lastEvent': 'Last event',
  'unlockWithAd': 'Watch ad',
  'recentlyUsed': 'Recently used',
  'recentlyUsedEmpty': 'Open a coloring page or puzzle to see it here.',
  'notifyTitle': 'A surprise awaits ✨',
  'notifyBody': 'Your daily sticker gift is ready — come pick a box!',
  'notifyStreakTitle': 'Keep the magic going!',
  'notifyStreakBody': 'Color a little today and keep your streak glowing.',
  'streakQuestTitle': 'Magic streak',
  'streakQuestTask': 'Today’s quest',
  'streakQuestDone': 'Done for today — your flame is glowing!',
  'streakQuestTodo': 'Color, puzzle, or open your daily gift once today.',
  'streakQuestHint': 'Come back every day to keep the flame alive.',
  'streakQuestClose': 'Got it!',
  'streakDays': '{n} day flame',
  'artworkInfoBody':
      'Every coloring page, puzzle image, and print template in Fairy Fantasy Color is an original creation made for this app. Thank you for coloring with us!',
  'feedbackHint': 'Tell us what you think…',
  'send': 'Send',
  'streakSemantics': '{n} day streak',
  'versionLabel': 'Version {v}\nSchwaben Apps',
};

const _de = {
  'muted': 'Stumm',
  'playing': 'Spielt',
  'music': 'Musik',
  'contactSupport': 'Support kontaktieren',
  'contactSupportSub': 'Problem melden und Hilfe bekommen',
  'sendFeedback': 'Feedback senden',
  'sendFeedbackSub': 'Ideen teilen oder ein Problem melden',
  'rateApp': 'Fairy Fantasy Color bewerten',
  'rateAppSub': 'Store-Seite öffnen',
  'resetStickers': 'Sticker-Album zurücksetzen',
  'resetStickersSub': 'Gesammelte Sticker und das Tagesgeschenk löschen',
  'originalArtwork': 'Originale Kunstwerke',
  'originalArtworkSub':
      'Alle Bilder in Fairy Fantasy Color sind Originalkreationen',
  'privacy': 'Datenschutz',
  'privacySub': 'So geht Fairy Fantasy Color mit deinen Daten um',
  'adPrivacy': 'Werbe-Privatsphäre',
  'adPrivacySubAvailable': 'Werbe-Einstellungen prüfen oder ändern',
  'adPrivacySubUnavailable':
      'Privatsphäre-Optionen öffnen, falls verfügbar',
  'terms': 'Nutzungsbedingungen',
  'termsSub': 'Regeln für Fairy Fantasy Color',
  'resetStickersTitle': 'Sticker-Album zurücksetzen?',
  'resetStickersBody':
      'Alle gesammelten Sticker und das heutige Tagesgeschenk werden gelöscht. Das kann nicht rückgängig gemacht werden.',
  'cancel': 'Abbrechen',
  'reset': 'Zurücksetzen',
  'stickersReset': 'Sticker-Album zurückgesetzt',
  'savedToPhotos': 'In Fotos gespeichert!',
  'saveToPhotos': 'In Fotos speichern',
  'done': 'Fertig',
  'colorMoreForDone': 'Male noch etwas weiter, um fertig zu werden und einen Sticker zu verdienen!',
  'colorBeforeSave': 'Male erst ein bisschen, bevor du speicherst.',
  'wonderful': 'Wunderbar!',
  'levelComplete': 'Level geschafft',
  'photos': 'Fotos',
  'asPuzzle': 'Als Puzzle',
  'couldNotLoadImage': 'Bild konnte nicht geladen werden',
  'pickAGift': 'Wähle ein Geschenk!',
  'eachBoxDifferent': 'In jeder Box steckt ein anderer Sticker',
  'newSticker': 'Neuer Sticker!',
  'dailySurprise': 'Tägliche Überraschung!',
  'pickBoxToday': 'Wähle eine Box für die heutige Belohnung',
  'dailyReward': 'Tagesbelohnung!',
  'stickerAlbum': 'Sticker-Album',
  'stickerRulesBody':
      '• Male ein Bild zu etwa 90 % aus, um einen Sticker zu verdienen — einmal pro Bild, bis du es zurücksetzt.\n'
      '• Löse ein Puzzle auf Pro-Schwierigkeit für einen Sticker — einmal pro Puzzle.\n'
      '• Easy- und Medium-Puzzles geben keine Sticker.\n'
      '• Jeden Tag kannst du eine Überraschungs-Box öffnen.\n'
      '• Jeder Sticker nur einmal — keine Duplikate.\n'
      '• Sammle alle, um das Sticker-Pack herunterzuladen.',
  'settings': 'Einstellungen',
  'welcomeTitle': 'Willkommen, kleiner\nAbenteurer!',
  'welcomeBody':
      'Eine Feenwelt wartet —\nmalen · puzzeln · entdecken\nin deinem Tempo.',
  'letsGo': 'Los geht’s!',
  'updateRequired': 'Update nötig',
  'updateNow': 'Jetzt updaten',
  'forceUpdateMessage':
      'Eine neue Version von Fairy Fantasy Color ist nötig.\nBitte aktualisiere im Store, um weiterzuspielen.',
  'home': 'Home',
  'color': 'Malen',
  'puzzle': 'Puzzle',
  'print': 'Drucken',
  'favorites': 'Favoriten',
  'newItems': 'Neu',
  'newColor': 'Neu Malen',
  'newPuzzle': 'Neu Puzzle',
  'lastEvent': 'Letztes Event',
  'unlockWithAd': 'Werbung',
  'recentlyUsed': 'Zuletzt benutzt',
  'recentlyUsedEmpty': 'Öffne ein Ausmalbild oder Puzzle, dann erscheint es hier.',
  'notifyTitle': 'Eine Überraschung wartet ✨',
  'notifyBody': 'Dein täglicher Sticker ist bereit — komm und wähle eine Box!',
  'notifyStreakTitle': 'Halte die Magie am Leben!',
  'notifyStreakBody': 'Male heute ein bisschen und lass deinen Streak leuchten.',
  'streakQuestTitle': 'Magie-Streak',
  'streakQuestTask': 'Heutige Aufgabe',
  'streakQuestDone': 'Für heute geschafft — deine Flamme leuchtet!',
  'streakQuestTodo': 'Male, puzzeln oder öffne heute einmal dein Tagesgeschenk.',
  'streakQuestHint': 'Komm jeden Tag vorbei, damit die Flamme weiterbrennt.',
  'streakQuestClose': 'Alles klar!',
  'streakDays': '{n}-Tage-Flamme',
  'artworkInfoBody':
      'Jedes Ausmalbild, Puzzle und jede Druckvorlage in Fairy Fantasy Color ist eine Originalkreation für diese App. Danke, dass du mit uns malst!',
  'feedbackHint': 'Erzähl uns, was du denkst…',
  'send': 'Senden',
  'streakSemantics': '{n}-Tage-Streak',
  'versionLabel': 'Version {v}\nSchwaben Apps',
};

const _es = {
  'muted': 'Silenciado',
  'playing': 'Sonando',
  'music': 'Música',
  'contactSupport': 'Contactar soporte',
  'contactSupportSub': 'Reporta un problema y recibe ayuda',
  'sendFeedback': 'Enviar comentarios',
  'sendFeedbackSub': 'Comparte ideas o reporta un problema',
  'rateApp': 'Valora Fairy Fantasy Color',
  'rateAppSub': 'Abrir la página de la tienda',
  'resetStickers': 'Restablecer álbum de stickers',
  'resetStickersSub': 'Borrar stickers y el regalo diario',
  'originalArtwork': 'Arte original',
  'originalArtworkSub':
      'Todas las imágenes de Fairy Fantasy Color son creaciones originales',
  'privacy': 'Privacidad',
  'privacySub': 'Cómo Fairy Fantasy Color trata tus datos',
  'adPrivacy': 'Privacidad de anuncios',
  'adPrivacySubAvailable': 'Revisar o cambiar ajustes de anuncios',
  'adPrivacySubUnavailable':
      'Abrir opciones de privacidad si están disponibles',
  'terms': 'Términos de uso',
  'termsSub': 'Reglas para usar Fairy Fantasy Color',
  'resetStickersTitle': '¿Restablecer álbum de stickers?',
  'resetStickersBody':
      'Se borrarán todos los stickers y el regalo de hoy. No se puede deshacer.',
  'cancel': 'Cancelar',
  'reset': 'Restablecer',
  'stickersReset': 'Álbum restablecido',
  'savedToPhotos': '¡Guardado en Fotos!',
  'saveToPhotos': 'Guardar en Fotos',
  'done': 'Listo',
  'colorMoreForDone': '¡Colorea un poco más para terminar y ganar un sticker!',
  'colorBeforeSave': 'Colorea un poco antes de guardar.',
  'wonderful': '¡Maravilloso!',
  'levelComplete': 'Nivel completado',
  'photos': 'Fotos',
  'asPuzzle': 'Como puzzle',
  'couldNotLoadImage': 'No se pudo cargar la imagen',
  'pickAGift': '¡Elige un regalo!',
  'eachBoxDifferent': 'Cada caja tiene un sticker distinto',
  'newSticker': '¡Nuevo sticker!',
  'dailySurprise': '¡Sorpresa diaria!',
  'pickBoxToday': 'Elige una caja para la recompensa de hoy',
  'dailyReward': '¡Recompensa diaria!',
  'stickerAlbum': 'Álbum de stickers',
  'stickerRulesBody':
      '• Termina un coloreable (~90 %) para ganar un sticker — una vez por imagen hasta reiniciarla.\n'
      '• Completa un puzzle en dificultad Pro para ganar un sticker — una vez por puzzle.\n'
      '• Easy y Medium no dan stickers.\n'
      '• Cada día puedes abrir una caja sorpresa.\n'
      '• Cada sticker solo una vez — sin duplicados.\n'
      '• Consíguelos todos para descargar el pack.',
  'settings': 'Ajustes',
  'welcomeTitle': '¡Bienvenido, pequeño\naventurero!',
  'welcomeBody':
      'Un mundo de hadas te espera —\ncolorea · puzzle · explora\na tu ritmo.',
  'letsGo': '¡Vamos!',
  'updateRequired': 'Actualización necesaria',
  'updateNow': 'Actualizar ahora',
  'forceUpdateMessage':
      'Se necesita una nueva versión de Fairy Fantasy Color.\nActualiza en la tienda para seguir jugando.',
  'home': 'Inicio',
  'color': 'Colorear',
  'puzzle': 'Puzzle',
  'print': 'Imprimir',
  'favorites': 'Favoritos',
  'newItems': 'Nuevo',
  'newColor': 'Nuevo colorear',
  'newPuzzle': 'Nuevo puzzle',
  'lastEvent': 'Último evento',
  'unlockWithAd': 'Ver anuncio',
  'recentlyUsed': 'Usado recientemente',
  'recentlyUsedEmpty': 'Abre un coloreable o puzzle para verlo aquí.',
  'notifyTitle': 'Hay una sorpresa ✨',
  'notifyBody': 'Tu sticker diario está listo — ¡ven a elegir una caja!',
  'notifyStreakTitle': '¡Sigue la magia!',
  'notifyStreakBody': 'Colorea un poco hoy y mantén tu racha brillante.',
  'streakQuestTitle': 'Racha mágica',
  'streakQuestTask': 'Misión de hoy',
  'streakQuestDone': '¡Hecho por hoy — tu llama brilla!',
  'streakQuestTodo': 'Colorea, haz un puzzle o abre tu regalo diario una vez hoy.',
  'streakQuestHint': 'Vuelve cada día para mantener la llama viva.',
  'streakQuestClose': '¡Entendido!',
  'streakDays': 'Llama de {n} días',
  'artworkInfoBody':
      'Cada página para colorear, puzzle y plantilla de impresión en Fairy Fantasy Color es una creación original. ¡Gracias por colorear con nosotros!',
  'feedbackHint': 'Cuéntanos qué piensas…',
  'send': 'Enviar',
  'streakSemantics': 'Racha de {n} días',
  'versionLabel': 'Versión {v}\nSchwaben Apps',
};

const _fr = {
  'muted': 'Muet',
  'playing': 'En lecture',
  'music': 'Musique',
  'contactSupport': 'Contacter le support',
  'contactSupportSub': 'Signaler un problème et obtenir de l’aide',
  'sendFeedback': 'Envoyer un avis',
  'sendFeedbackSub': 'Partager une idée ou un problème',
  'rateApp': 'Noter Fairy Fantasy Color',
  'rateAppSub': 'Ouvrir la page du store',
  'resetStickers': 'Réinitialiser l’album',
  'resetStickersSub': 'Effacer les stickers et le cadeau du jour',
  'originalArtwork': 'Œuvres originales',
  'originalArtworkSub':
      'Toutes les images de Fairy Fantasy Color sont des créations originales',
  'privacy': 'Confidentialité',
  'privacySub': 'Comment Fairy Fantasy Color traite vos données',
  'adPrivacy': 'Confidentialité des pubs',
  'adPrivacySubAvailable': 'Voir ou modifier les réglages pubs',
  'adPrivacySubUnavailable':
      'Ouvrir les choix de confidentialité si disponibles',
  'terms': 'Conditions d’utilisation',
  'termsSub': 'Règles pour Fairy Fantasy Color',
  'resetStickersTitle': 'Réinitialiser l’album ?',
  'resetStickersBody':
      'Tous les stickers et le cadeau du jour seront effacés. Irréversible.',
  'cancel': 'Annuler',
  'reset': 'Réinitialiser',
  'stickersReset': 'Album réinitialisé',
  'savedToPhotos': 'Enregistré dans Photos !',
  'saveToPhotos': 'Enregistrer dans Photos',
  'done': 'Terminé',
  'colorMoreForDone': 'Colorie encore un peu pour terminer et gagner un sticker !',
  'colorBeforeSave': 'Colorie un peu avant d’enregistrer.',
  'wonderful': 'Merveilleux !',
  'levelComplete': 'Niveau terminé',
  'photos': 'Photos',
  'asPuzzle': 'En puzzle',
  'couldNotLoadImage': 'Impossible de charger l’image',
  'pickAGift': 'Choisis un cadeau !',
  'eachBoxDifferent': 'Chaque boîte cache un sticker différent',
  'newSticker': 'Nouveau sticker !',
  'dailySurprise': 'Surprise du jour !',
  'pickBoxToday': 'Choisis une boîte pour la récompense du jour',
  'dailyReward': 'Récompense du jour !',
  'stickerAlbum': 'Album de stickers',
  'stickerRulesBody':
      '• Termine un coloriage (~90 %) pour gagner un sticker — une fois par image jusqu’à reset.\n'
      '• Finis un puzzle en difficulté Pro pour un sticker — une fois par puzzle.\n'
      '• Easy et Medium ne donnent pas de stickers.\n'
      '• Chaque jour, ouvre une boîte surprise.\n'
      '• Chaque sticker une seule fois — pas de doublons.\n'
      '• Collecte-les tous pour télécharger le pack.',
  'settings': 'Réglages',
  'welcomeTitle': 'Bienvenue, petit\naventurier !',
  'welcomeBody':
      'Un monde de fées t’attend —\ncolorie · puzzle · explore\nà ton rythme.',
  'letsGo': 'C’est parti !',
  'updateRequired': 'Mise à jour requise',
  'updateNow': 'Mettre à jour',
  'forceUpdateMessage':
      'Une nouvelle version de Fairy Fantasy Color est requise.\nMets à jour dans le store pour continuer.',
  'home': 'Accueil',
  'color': 'Colorier',
  'puzzle': 'Puzzle',
  'print': 'Imprimer',
  'favorites': 'Favoris',
  'newItems': 'Nouveau',
  'newColor': 'Nouveau coloriage',
  'newPuzzle': 'Nouveau puzzle',
  'lastEvent': 'Dernier événement',
  'unlockWithAd': 'Voir pub',
  'recentlyUsed': 'Récemment utilisé',
  'recentlyUsedEmpty': 'Ouvre un coloriage ou un puzzle pour le voir ici.',
  'notifyTitle': 'Une surprise t’attend ✨',
  'notifyBody': 'Ton sticker du jour est prêt — viens choisir une boîte !',
  'notifyStreakTitle': 'Garde la magie vivante !',
  'notifyStreakBody': 'Colorie un peu aujourd’hui et garde ta série.',
  'streakQuestTitle': 'Série magique',
  'streakQuestTask': 'Quête du jour',
  'streakQuestDone': 'Fait pour aujourd’hui — ta flamme brille !',
  'streakQuestTodo': 'Colorie, fais un puzzle ou ouvre ton cadeau du jour une fois.',
  'streakQuestHint': 'Reviens chaque jour pour garder la flamme allumée.',
  'streakQuestClose': 'Compris !',
  'streakDays': 'Flamme de {n} jours',
  'artworkInfoBody':
      'Chaque page à colorier, puzzle et modèle d’impression dans Fairy Fantasy Color est une création originale. Merci de colorier avec nous !',
  'feedbackHint': 'Dis-nous ce que tu penses…',
  'send': 'Envoyer',
  'streakSemantics': 'Série de {n} jours',
  'versionLabel': 'Version {v}\nSchwaben Apps',
};

const _pt = {
  'muted': 'Sem som',
  'playing': 'A tocar',
  'music': 'Música',
  'contactSupport': 'Contactar apoio',
  'contactSupportSub': 'Reportar um problema e obter ajuda',
  'sendFeedback': 'Enviar feedback',
  'sendFeedbackSub': 'Partilhar ideias ou reportar um problema',
  'rateApp': 'Avaliar Fairy Fantasy Color',
  'rateAppSub': 'Abrir a página da loja',
  'resetStickers': 'Repor álbum de stickers',
  'resetStickersSub': 'Limpar stickers e o presente diário',
  'originalArtwork': 'Arte original',
  'originalArtworkSub':
      'Todas as imagens de Fairy Fantasy Color são criações originais',
  'privacy': 'Privacidade',
  'privacySub': 'Como o Fairy Fantasy Color trata os teus dados',
  'adPrivacy': 'Privacidade de anúncios',
  'adPrivacySubAvailable': 'Rever ou alterar definições de anúncios',
  'adPrivacySubUnavailable':
      'Abrir opções de privacidade quando disponíveis',
  'terms': 'Termos de utilização',
  'termsSub': 'Regras para usar Fairy Fantasy Color',
  'resetStickersTitle': 'Repor álbum de stickers?',
  'resetStickersBody':
      'Todos os stickers e o presente de hoje serão apagados. Não se pode desfazer.',
  'cancel': 'Cancelar',
  'reset': 'Repor',
  'stickersReset': 'Álbum reposto',
  'savedToPhotos': 'Guardado nas Fotos!',
  'saveToPhotos': 'Guardar nas Fotos',
  'done': 'Concluído',
  'colorMoreForDone': 'Colorir um pouco mais para terminar e ganhar um sticker!',
  'colorBeforeSave': 'Colorir um pouco antes de guardar.',
  'wonderful': 'Maravilhoso!',
  'levelComplete': 'Nível concluído',
  'photos': 'Fotos',
  'asPuzzle': 'Como puzzle',
  'couldNotLoadImage': 'Não foi possível carregar a imagem',
  'pickAGift': 'Escolhe um presente!',
  'eachBoxDifferent': 'Cada caixa tem um sticker diferente',
  'newSticker': 'Novo sticker!',
  'dailySurprise': 'Surpresa diária!',
  'pickBoxToday': 'Escolhe uma caixa para a recompensa de hoje',
  'dailyReward': 'Recompensa diária!',
  'stickerAlbum': 'Álbum de stickers',
  'stickerRulesBody':
      '• Termina um colorir (~90 %) para ganhar um sticker — uma vez por imagem até reiniciar.\n'
      '• Completa um puzzle em dificuldade Pro para um sticker — uma vez por puzzle.\n'
      '• Easy e Medium não dão stickers.\n'
      '• Todos os dias podes abrir uma caixa surpresa.\n'
      '• Cada sticker só uma vez — sem duplicados.\n'
      '• Junta todos para descarregar o pack.',
  'settings': 'Definições',
  'welcomeTitle': 'Bem-vindo, pequeno\naventureiro!',
  'welcomeBody':
      'Um mundo de fadas espera —\ncolorir · puzzle · explorar\nao teu ritmo.',
  'letsGo': 'Vamos!',
  'updateRequired': 'Atualização necessária',
  'updateNow': 'Atualizar agora',
  'forceUpdateMessage':
      'É necessária uma nova versão de Fairy Fantasy Color.\nAtualiza na loja para continuar a jogar.',
  'home': 'Início',
  'color': 'Colorir',
  'puzzle': 'Puzzle',
  'print': 'Imprimir',
  'favorites': 'Favoritos',
  'newItems': 'Novo',
  'newColor': 'Novo colorir',
  'newPuzzle': 'Novo puzzle',
  'lastEvent': 'Último evento',
  'unlockWithAd': 'Ver anúncio',
  'recentlyUsed': 'Usado recentemente',
  'recentlyUsedEmpty': 'Abre um colorir ou puzzle para o ver aqui.',
  'notifyTitle': 'Uma surpresa espera ✨',
  'notifyBody': 'O teu sticker diário está pronto — vem escolher uma caixa!',
  'notifyStreakTitle': 'Mantém a magia!',
  'notifyStreakBody': 'Colorir um pouco hoje e mantém a tua sequência.',
  'streakQuestTitle': 'Sequência mágica',
  'streakQuestTask': 'Missão de hoje',
  'streakQuestDone': 'Feito por hoje — a tua chama brilha!',
  'streakQuestTodo': 'Colorir, fazer um puzzle ou abrir o presente diário uma vez hoje.',
  'streakQuestHint': 'Volta todos os dias para manter a chama acesa.',
  'streakQuestClose': 'Percebi!',
  'streakDays': 'Chama de {n} dias',
  'artworkInfoBody':
      'Cada página para colorir, puzzle e modelo de impressão no Fairy Fantasy Color é uma criação original. Obrigado por colorir connosco!',
  'feedbackHint': 'Diz-nos o que pensas…',
  'send': 'Enviar',
  'streakSemantics': 'Sequência de {n} dias',
  'versionLabel': 'Versão {v}\nSchwaben Apps',
};

const _it = {
  'muted': 'Muto',
  'playing': 'In riproduzione',
  'music': 'Musica',
  'contactSupport': 'Contatta il supporto',
  'contactSupportSub': 'Segnala un problema e ricevi aiuto',
  'sendFeedback': 'Invia feedback',
  'sendFeedbackSub': 'Condividi idee o segnala un problema',
  'rateApp': 'Valuta Fairy Fantasy Color',
  'rateAppSub': 'Apri la pagina dello store',
  'resetStickers': 'Reimposta album sticker',
  'resetStickersSub': 'Cancella sticker e il regalo giornaliero',
  'originalArtwork': 'Opere originali',
  'originalArtworkSub':
      'Tutte le immagini di Fairy Fantasy Color sono creazioni originali',
  'privacy': 'Privacy',
  'privacySub': 'Come Fairy Fantasy Color gestisce i tuoi dati',
  'adPrivacy': 'Privacy annunci',
  'adPrivacySubAvailable': 'Rivedi o modifica le impostazioni annunci',
  'adPrivacySubUnavailable':
      'Apri le scelte privacy quando disponibili',
  'terms': 'Termini di utilizzo',
  'termsSub': 'Regole per Fairy Fantasy Color',
  'resetStickersTitle': 'Reimpostare l’album sticker?',
  'resetStickersBody':
      'Tutti gli sticker e il regalo di oggi verranno cancellati. Non si può annullare.',
  'cancel': 'Annulla',
  'reset': 'Reimposta',
  'stickersReset': 'Album reimpostato',
  'savedToPhotos': 'Salvato in Foto!',
  'saveToPhotos': 'Salva in Foto',
  'done': 'Fatto',
  'colorMoreForDone': 'Colora ancora un po’ per finire e guadagnare uno sticker!',
  'colorBeforeSave': 'Colora un po’ prima di salvare.',
  'wonderful': 'Meraviglioso!',
  'levelComplete': 'Livello completato',
  'photos': 'Foto',
  'asPuzzle': 'Come puzzle',
  'couldNotLoadImage': 'Impossibile caricare l’immagine',
  'pickAGift': 'Scegli un regalo!',
  'eachBoxDifferent': 'Ogni scatola nasconde uno sticker diverso',
  'newSticker': 'Nuovo sticker!',
  'dailySurprise': 'Sorpresa del giorno!',
  'pickBoxToday': 'Scegli una scatola per la ricompensa di oggi',
  'dailyReward': 'Ricompensa del giorno!',
  'stickerAlbum': 'Album sticker',
  'stickerRulesBody':
      '• Completa un disegno (~90 %) per uno sticker — una volta per immagine fino al reset.\n'
      '• Risolvi un puzzle in difficoltà Pro per uno sticker — una volta per puzzle.\n'
      '• Easy e Medium non danno sticker.\n'
      '• Ogni giorno puoi aprire una scatola sorpresa.\n'
      '• Ogni sticker una sola volta — niente duplicati.\n'
      '• Collezionali tutti per scaricare il pack.',
  'settings': 'Impostazioni',
  'welcomeTitle': 'Benvenuto, piccolo\navventuriero!',
  'welcomeBody':
      'Un mondo di fate ti aspetta —\ncolora · puzzle · esplora\nal tuo ritmo.',
  'letsGo': 'Andiamo!',
  'updateRequired': 'Aggiornamento richiesto',
  'updateNow': 'Aggiorna ora',
  'forceUpdateMessage':
      'È richiesta una nuova versione di Fairy Fantasy Color.\nAggiorna nello store per continuare.',
  'home': 'Home',
  'color': 'Colora',
  'puzzle': 'Puzzle',
  'print': 'Stampa',
  'favorites': 'Preferiti',
  'newItems': 'Nuovo',
  'newColor': 'Nuovo colorare',
  'newPuzzle': 'Nuovo puzzle',
  'lastEvent': 'Ultimo evento',
  'unlockWithAd': 'Guarda ads',
  'recentlyUsed': 'Usati di recente',
  'recentlyUsedEmpty': 'Apri un disegno o un puzzle per vederlo qui.',
  'notifyTitle': 'Ti aspetta una sorpresa ✨',
  'notifyBody': 'Il tuo sticker giornaliero è pronto — vieni a scegliere!',
  'notifyStreakTitle': 'Tieni viva la magia!',
  'notifyStreakBody': 'Colora un po’ oggi e mantieni la serie.',
  'streakQuestTitle': 'Serie magica',
  'streakQuestTask': 'Missione di oggi',
  'streakQuestDone': 'Fatto per oggi — la tua fiamma brilla!',
  'streakQuestTodo': 'Colora, fai un puzzle o apri il regalo giornaliero una volta oggi.',
  'streakQuestHint': 'Torna ogni giorno per tenere viva la fiamma.',
  'streakQuestClose': 'Capito!',
  'streakDays': 'Fiamma di {n} giorni',
  'artworkInfoBody':
      'Ogni pagina da colorare, puzzle e modello di stampa in Fairy Fantasy Color è una creazione originale. Grazie per colorare con noi!',
  'feedbackHint': 'Dicci cosa ne pensi…',
  'send': 'Invia',
  'streakSemantics': 'Serie di {n} giorni',
  'versionLabel': 'Versione {v}\nSchwaben Apps',
};

const _nl = {
  'muted': 'Gedempt',
  'playing': 'Speelt',
  'music': 'Muziek',
  'contactSupport': 'Support contacteren',
  'contactSupportSub': 'Meld een probleem en krijg hulp',
  'sendFeedback': 'Feedback sturen',
  'sendFeedbackSub': 'Deel ideeën of meld een probleem',
  'rateApp': 'Beoordeel Fairy Fantasy Color',
  'rateAppSub': 'Open de storepagina',
  'resetStickers': 'Stickeralbum resetten',
  'resetStickersSub': 'Verwijder stickers en het dagelijkse cadeau',
  'originalArtwork': 'Originele kunst',
  'originalArtworkSub':
      'Alle afbeeldingen in Fairy Fantasy Color zijn originele creaties',
  'privacy': 'Privacy',
  'privacySub': 'Hoe Fairy Fantasy Color met je gegevens omgaat',
  'adPrivacy': 'Advertentieprivacy',
  'adPrivacySubAvailable': 'Advertentie-instellingen bekijken of wijzigen',
  'adPrivacySubUnavailable':
      'Privacykeuzes openen indien beschikbaar',
  'terms': 'Gebruiksvoorwaarden',
  'termsSub': 'Regels voor Fairy Fantasy Color',
  'resetStickersTitle': 'Stickeralbum resetten?',
  'resetStickersBody':
      'Alle stickers en het cadeau van vandaag worden gewist. Dit kan niet ongedaan worden gemaakt.',
  'cancel': 'Annuleren',
  'reset': 'Resetten',
  'stickersReset': 'Album gereset',
  'savedToPhotos': 'Opgeslagen in Foto’s!',
  'saveToPhotos': 'Opslaan in Foto’s',
  'done': 'Klaar',
  'colorMoreForDone': 'Kleur nog wat meer om klaar te zijn en een sticker te verdienen!',
  'colorBeforeSave': 'Kleur eerst een beetje voordat je opslaat.',
  'wonderful': 'Geweldig!',
  'levelComplete': 'Level voltooid',
  'photos': 'Foto’s',
  'asPuzzle': 'Als puzzel',
  'couldNotLoadImage': 'Afbeelding kon niet worden geladen',
  'pickAGift': 'Kies een cadeau!',
  'eachBoxDifferent': 'Elke doos heeft een andere sticker',
  'newSticker': 'Nieuwe sticker!',
  'dailySurprise': 'Dagelijkse verrassing!',
  'pickBoxToday': 'Kies een doos voor de beloning van vandaag',
  'dailyReward': 'Dagelijkse beloning!',
  'stickerAlbum': 'Stickeralbum',
  'stickerRulesBody':
      '• Maak een kleurplaat (~90 %) af voor een sticker — één keer per plaat tot reset.\n'
      '• Maak een puzzel op Pro-niveau af voor een sticker — één keer per puzzel.\n'
      '• Easy en Medium geven geen stickers.\n'
      '• Elke dag kun je een verrassingsdoos openen.\n'
      '• Elke sticker maar één keer — geen duplicaten.\n'
      '• Verzamel ze allemaal om het pack te downloaden.',
  'settings': 'Instellingen',
  'welcomeTitle': 'Welkom, kleine\navonturier!',
  'welcomeBody':
      'Een feeënwereld wacht —\nkleur · puzzel · ontdek\nin je eigen tempo.',
  'letsGo': 'Laten we gaan!',
  'updateRequired': 'Update vereist',
  'updateNow': 'Nu updaten',
  'forceUpdateMessage':
      'Er is een nieuwe versie van Fairy Fantasy Color nodig.\nUpdate in de store om verder te spelen.',
  'home': 'Home',
  'color': 'Kleuren',
  'puzzle': 'Puzzel',
  'print': 'Printen',
  'favorites': 'Favorieten',
  'newItems': 'Nieuw',
  'newColor': 'Nieuw kleuren',
  'newPuzzle': 'Nieuwe puzzel',
  'lastEvent': 'Laatste event',
  'unlockWithAd': 'Advertentie',
  'recentlyUsed': 'Recent gebruikt',
  'recentlyUsedEmpty': 'Open een kleurplaat of puzzel om die hier te zien.',
  'notifyTitle': 'Er wacht een verrassing ✨',
  'notifyBody': 'Je dagelijkse sticker is klaar — kom een doos kiezen!',
  'notifyStreakTitle': 'Houd de magie levend!',
  'notifyStreakBody': 'Kleur vandaag een beetje en houd je reeks gaande.',
  'streakQuestTitle': 'Magische reeks',
  'streakQuestTask': 'Quest van vandaag',
  'streakQuestDone': 'Klaar voor vandaag — jouw vlam gloeit!',
  'streakQuestTodo': 'Kleur, puzzel of open vandaag één keer je dagelijkse cadeau.',
  'streakQuestHint': 'Kom elke dag terug om de vlam levend te houden.',
  'streakQuestClose': 'Begrepen!',
  'streakDays': '{n}-dagenvlam',
  'artworkInfoBody':
      'Elke kleurplaat, puzzel en printtemplate in Fairy Fantasy Color is een originele creatie. Bedankt dat je met ons kleurt!',
  'feedbackHint': 'Vertel ons wat je denkt…',
  'send': 'Versturen',
  'streakSemantics': '{n}-dagenreeks',
  'versionLabel': 'Versie {v}\nSchwaben Apps',
};

const _pl = {
  'muted': 'Wyciszone',
  'playing': 'Odtwarzanie',
  'music': 'Muzyka',
  'contactSupport': 'Kontakt z pomocą',
  'contactSupportSub': 'Zgłoś problem i uzyskaj pomoc',
  'sendFeedback': 'Wyślij opinię',
  'sendFeedbackSub': 'Podziel się pomysłem lub zgłoś problem',
  'rateApp': 'Oceń Fairy Fantasy Color',
  'rateAppSub': 'Otwórz stronę sklepu',
  'resetStickers': 'Resetuj album naklejek',
  'resetStickersSub': 'Wyczyść naklejki i codzienny prezent',
  'originalArtwork': 'Oryginalna grafika',
  'originalArtworkSub':
      'Wszystkie obrazy w Fairy Fantasy Color to oryginalne dzieła',
  'privacy': 'Prywatność',
  'privacySub': 'Jak Fairy Fantasy Color przetwarza dane',
  'adPrivacy': 'Prywatność reklam',
  'adPrivacySubAvailable': 'Sprawdź lub zmień ustawienia reklam',
  'adPrivacySubUnavailable':
      'Otwórz opcje prywatności, gdy są dostępne',
  'terms': 'Warunki użytkowania',
  'termsSub': 'Zasady Fairy Fantasy Color',
  'resetStickersTitle': 'Zresetować album naklejek?',
  'resetStickersBody':
      'Wszystkie naklejki i dzisiejszy prezent zostaną usunięte. Nie można cofnąć.',
  'cancel': 'Anuluj',
  'reset': 'Resetuj',
  'stickersReset': 'Album zresetowany',
  'savedToPhotos': 'Zapisano w Zdjęciach!',
  'saveToPhotos': 'Zapisz w Zdjęciach',
  'done': 'Gotowe',
  'colorMoreForDone': 'Pokoloruj jeszcze trochę, by skończyć i zdobyć naklejkę!',
  'colorBeforeSave': 'Pokoloruj trochę, zanim zapiszesz.',
  'wonderful': 'Wspaniale!',
  'levelComplete': 'Poziom ukończony',
  'photos': 'Zdjęcia',
  'asPuzzle': 'Jako puzzle',
  'couldNotLoadImage': 'Nie udało się wczytać obrazu',
  'pickAGift': 'Wybierz prezent!',
  'eachBoxDifferent': 'W każdym pudełku inna naklejka',
  'newSticker': 'Nowa naklejka!',
  'dailySurprise': 'Codzienna niespodzianka!',
  'pickBoxToday': 'Wybierz pudełko na dzisiejszą nagrodę',
  'dailyReward': 'Codzienna nagroda!',
  'stickerAlbum': 'Album naklejek',
  'stickerRulesBody':
      '• Ukończ kolorowankę (~90 %), by zdobyć naklejkę — raz na obraz do resetu.\n'
      '• Ułóż puzzle na poziomie Pro, by zdobyć naklejkę — raz na puzzle.\n'
      '• Easy i Medium nie dają naklejek.\n'
      '• Codziennie możesz otworzyć niespodziankę.\n'
      '• Każda naklejka tylko raz — bez duplikatów.\n'
      '• Zbierz wszystkie, by pobrać paczkę.',
  'settings': 'Ustawienia',
  'welcomeTitle': 'Witaj, mały\npodróżniku!',
  'welcomeBody':
      'Czeka świat wróżek —\nkoloruj · układaj · odkrywaj\nwe własnym tempie.',
  'letsGo': 'Zaczynamy!',
  'updateRequired': 'Wymagana aktualizacja',
  'updateNow': 'Aktualizuj teraz',
  'forceUpdateMessage':
      'Potrzebna jest nowa wersja Fairy Fantasy Color.\nZaktualizuj w sklepie, aby grać dalej.',
  'home': 'Start',
  'color': 'Koloruj',
  'puzzle': 'Puzzle',
  'print': 'Drukuj',
  'favorites': 'Ulubione',
  'newItems': 'Nowe',
  'newColor': 'Nowe kolorowanie',
  'newPuzzle': 'Nowe puzzle',
  'lastEvent': 'Ostatnie wydarzenie',
  'unlockWithAd': 'Reklama',
  'recentlyUsed': 'Ostatnio używane',
  'recentlyUsedEmpty': 'Otwórz kolorowankę lub puzzle, by zobaczyć je tutaj.',
  'notifyTitle': 'Czeka niespodzianka ✨',
  'notifyBody': 'Codzienna naklejka jest gotowa — wybierz pudełko!',
  'notifyStreakTitle': 'Utrzymaj magię!',
  'notifyStreakBody': 'Pokoloruj dziś trochę i utrzymaj serię.',
  'streakQuestTitle': 'Magiczna seria',
  'streakQuestTask': 'Dzisiejsze zadanie',
  'streakQuestDone': 'Na dziś gotowe — twój płomień świeci!',
  'streakQuestTodo': 'Pokoloruj, ułóż puzzle lub otwórz dziś raz codzienny prezent.',
  'streakQuestHint': 'Wracaj codziennie, by utrzymać płomień.',
  'streakQuestClose': 'Rozumiem!',
  'streakDays': 'Płomień {n} dni',
  'artworkInfoBody':
      'Każda kolorowanka, puzzle i szablon do druku w Fairy Fantasy Color to oryginalne dzieło. Dziękujemy, że kolorujesz z nami!',
  'feedbackHint': 'Powiedz nam, co myślisz…',
  'send': 'Wyślij',
  'streakSemantics': 'Seria {n} dni',
  'versionLabel': 'Wersja {v}\nSchwaben Apps',
};

const _tr = {
  'muted': 'Sessiz',
  'playing': 'Çalıyor',
  'music': 'Müzik',
  'contactSupport': 'Destek ile iletişim',
  'contactSupportSub': 'Sorun bildir ve yardım al',
  'sendFeedback': 'Geri bildirim gönder',
  'sendFeedbackSub': 'Fikir paylaş veya sorun bildir',
  'rateApp': 'Fairy Fantasy Color’ı değerlendir',
  'rateAppSub': 'Mağaza sayfasını aç',
  'resetStickers': 'Çıkartma albümünü sıfırla',
  'resetStickersSub': 'Çıkartmaları ve günlük hediyeyi temizle',
  'originalArtwork': 'Orijinal sanat',
  'originalArtworkSub':
      'Fairy Fantasy Color’daki tüm görseller orijinal eserlerdir',
  'privacy': 'Gizlilik',
  'privacySub': 'Fairy Fantasy Color verilerini nasıl işler',
  'adPrivacy': 'Reklam gizliliği',
  'adPrivacySubAvailable': 'Reklam ayarlarını incele veya değiştir',
  'adPrivacySubUnavailable':
      'Mümkünse gizlilik seçeneklerini aç',
  'terms': 'Kullanım şartları',
  'termsSub': 'Fairy Fantasy Color kuralları',
  'resetStickersTitle': 'Çıkartma albümü sıfırlansın mı?',
  'resetStickersBody':
      'Tüm çıkartmalar ve bugünkü hediye silinecek. Geri alınamaz.',
  'cancel': 'İptal',
  'reset': 'Sıfırla',
  'stickersReset': 'Albüm sıfırlandı',
  'savedToPhotos': 'Fotoğraflara kaydedildi!',
  'saveToPhotos': 'Fotoğraflara kaydet',
  'done': 'Bitti',
  'colorMoreForDone': 'Bitirmek ve sticker kazanmak için biraz daha boya!',
  'colorBeforeSave': 'Kaydetmeden önce biraz boya.',
  'wonderful': 'Harika!',
  'levelComplete': 'Seviye tamamlandı',
  'photos': 'Fotoğraflar',
  'asPuzzle': 'Yapboz olarak',
  'couldNotLoadImage': 'Görsel yüklenemedi',
  'pickAGift': 'Bir hediye seç!',
  'eachBoxDifferent': 'Her kutuda farklı bir çıkartma var',
  'newSticker': 'Yeni çıkartma!',
  'dailySurprise': 'Günlük sürpriz!',
  'pickBoxToday': 'Bugünün ödülü için bir kutu seç',
  'dailyReward': 'Günlük ödül!',
  'stickerAlbum': 'Çıkartma albümü',
  'stickerRulesBody':
      '• Yaklaşık %90 boyayınca sticker kazanırsın — sıfırlayana kadar resim başına bir kez.\n'
      '• Pro zorlukta puzzle bitirince sticker — puzzle başına bir kez.\n'
      '• Easy ve Medium sticker vermez.\n'
      '• Her gün sürpriz kutu açabilirsin.\n'
      '• Her sticker yalnızca bir kez — kopya yok.\n'
      '• Hepsini topla, paketi indir.',
  'settings': 'Ayarlar',
  'welcomeTitle': 'Hoş geldin, küçük\nmaceracı!',
  'welcomeBody':
      'Bir peri dünyası seni bekliyor —\nboyama · yapboz · keşif\nkendi temposunda.',
  'letsGo': 'Hadi!',
  'updateRequired': 'Güncelleme gerekli',
  'updateNow': 'Şimdi güncelle',
  'forceUpdateMessage':
      'Fairy Fantasy Color’ın yeni bir sürümü gerekli.\nOynamaya devam etmek için mağazadan güncelle.',
  'home': 'Ana sayfa',
  'color': 'Boyama',
  'puzzle': 'Yapboz',
  'print': 'Yazdır',
  'favorites': 'Favoriler',
  'newItems': 'Yeni',
  'newColor': 'Yeni boyama',
  'newPuzzle': 'Yeni yapboz',
  'lastEvent': 'Son etkinlik',
  'unlockWithAd': 'Reklam izle',
  'recentlyUsed': 'Son kullanılanlar',
  'recentlyUsedEmpty': 'Burada görmek için bir boyama veya yapboz aç.',
  'notifyTitle': 'Bir sürpriz seni bekliyor ✨',
  'notifyBody': 'Günlük çıkartman hazır — gel bir kutu seç!',
  'notifyStreakTitle': 'Sihri sürdürmeye devam!',
  'notifyStreakBody': 'Bugün biraz boya ve serini koru.',
  'streakQuestTitle': 'Sihirli seri',
  'streakQuestTask': 'Bugünün görevi',
  'streakQuestDone': 'Bugün tamam — alevin parlıyor!',
  'streakQuestTodo': 'Bugün bir kez boya, yapboz yap veya günlük hediyeyi aç.',
  'streakQuestHint': 'Alevin yanması için her gün geri gel.',
  'streakQuestClose': 'Anladım!',
  'streakDays': '{n} günlük alev',
  'artworkInfoBody':
      'Fairy Fantasy Color’daki her boyama sayfası, yapboz ve yazdırma şablonu orijinal bir eserdir. Bizimle boyadığın için teşekkürler!',
  'feedbackHint': 'Ne düşündüğünü söyle…',
  'send': 'Gönder',
  'streakSemantics': '{n} günlük seri',
  'versionLabel': 'Sürüm {v}\nSchwaben Apps',
};
