// File generated manually for Fantasy Color (Firebase project games-8eea5).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfLLDvxD8VdzOJhGhMrL_K_q_ffgfPt9U',
    appId: '1:331574872265:android:bd34e6f7a547e1eb786518',
    messagingSenderId: '331574872265',
    projectId: 'games-8eea5',
    storageBucket: 'games-8eea5.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB8YjIi1HkaisdlMrxvYiOSFNbZLhLGv-Y',
    appId: '1:331574872265:ios:6d0b48ebb5b5d1aa786518',
    messagingSenderId: '331574872265',
    projectId: 'games-8eea5',
    storageBucket: 'games-8eea5.firebasestorage.app',
    iosBundleId: 'com.schwabenapps.mkz.fantasyColor',
  );
}
