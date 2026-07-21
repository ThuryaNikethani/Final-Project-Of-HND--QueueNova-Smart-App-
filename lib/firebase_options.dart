import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android configuration from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB_902Yga1UzWexf-TCBJdcFYiLFcphS8U',
    appId: '1:346916174556:android:0f2faca06d6591f11c9219',
    messagingSenderId: '346916174556',
    projectId: 'queuenova-78ca8',
    storageBucket: 'queuenova-78ca8.firebasestorage.app',
  );

  // Web configuration (same project, web app key)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB_902Yga1UzWexf-TCBJdcFYiLFcphS8U',
    appId: '1:346916174556:web:f2d981cd5084fa721c9219',
    messagingSenderId: '346916174556',
    projectId: 'queuenova-78ca8',
    authDomain: 'queuenova-78ca8.firebaseapp.com',
    storageBucket: 'queuenova-78ca8.firebasestorage.app',
  );
}
