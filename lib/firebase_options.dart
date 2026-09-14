import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'firebase_env.dart';

class DefaultFirebaseOptions {
  static String _env(String key, [String? fallback]) {
    return FirebaseEnv.get(key, fallback ?? '');
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _env('FIREBASE_WEB_API_KEY', 'YOUR_WEB_API_KEY'),
        appId: _env('FIREBASE_WEB_APP_ID', 'YOUR_WEB_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID', 'YOUR_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID', 'your-project-id'),
        authDomain: _env('FIREBASE_AUTH_DOMAIN', 'your-project-id.firebaseapp.com'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET', 'your-project-id.firebasestorage.app'),
        measurementId: _env('FIREBASE_MEASUREMENT_ID', 'YOUR_MEASUREMENT_ID'),
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _env('FIREBASE_ANDROID_API_KEY', _env('FIREBASE_WEB_API_KEY', 'YOUR_ANDROID_API_KEY')),
        appId: _env('FIREBASE_ANDROID_APP_ID', _env('FIREBASE_WEB_APP_ID', 'YOUR_ANDROID_APP_ID')),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID', 'YOUR_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID', 'your-project-id'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET', 'your-project-id.firebasestorage.app'),
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _env('FIREBASE_IOS_API_KEY', _env('FIREBASE_WEB_API_KEY', 'YOUR_IOS_API_KEY')),
        appId: _env('FIREBASE_IOS_APP_ID', _env('FIREBASE_WEB_APP_ID', 'YOUR_IOS_APP_ID')),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID', 'YOUR_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID', 'your-project-id'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET', 'your-project-id.firebasestorage.app'),
        iosBundleId: _env('IOS_BUNDLE_ID', 'com.example.sflms'),
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: _env('FIREBASE_WINDOWS_API_KEY', _env('FIREBASE_WEB_API_KEY', 'YOUR_WINDOWS_API_KEY')),
        appId: _env('FIREBASE_WINDOWS_APP_ID', _env('FIREBASE_WEB_APP_ID', 'YOUR_WINDOWS_APP_ID')),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID', 'YOUR_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID', 'your-project-id'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET', 'your-project-id.firebasestorage.app'),
      );
}
