import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyCCFPugxPzZIih2wIC7W4Vqcj-X8S2_Tkk',
      appId: '1:1032501750236:web:02563becdc60bab98f0719',
      messagingSenderId: '1032501750236',
      projectId: 'giveme-5e950',
      authDomain: 'giveme-5e950.firebaseapp.com',
      databaseURL: 'https://giveme-5e950-default-rtdb.firebaseio.com',
      storageBucket: 'giveme-5e950.appspot.com',
      measurementId: 'G-QDVPGH1CD8',
    );
  }
}
