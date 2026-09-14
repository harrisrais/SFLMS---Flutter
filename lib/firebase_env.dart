class FirebaseEnv {
  static final Map<String, String> _config = {
    'FIREBASE_PROJECT_ID': 'sflms-dfa70',
    'FIREBASE_WEB_API_KEY': 'AIzaSyBZiUUS9igNtl7ZMj_JdNXMZ0U1ItG9Mck',
    'FIREBASE_WEB_APP_ID': '1:805954624299:web:d1156e2af947158611c36e',
    'FIREBASE_MESSAGING_SENDER_ID': '805954624299',
    'FIREBASE_AUTH_DOMAIN': 'sflms-dfa70.firebaseapp.com',
    'FIREBASE_STORAGE_BUCKET': 'sflms-dfa70.firebasestorage.app',
    'FIREBASE_MEASUREMENT_ID': 'G-YEWC4BWP1W',
    // Update Android / iOS / Windows keys as well if you are using them
  };

  static String get(String key, [String fallback = '']) {
    return _config[key] ?? fallback;
  }
}