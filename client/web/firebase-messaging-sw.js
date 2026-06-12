// Give this service worker access to Firebase Messaging.
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker
firebase.initializeApp({
  apiKey: 'AIzaSyCCFPugxPzZIih2wIC7W4Vqcj-X8S2_Tkk',
  appId: '1:1032501750236:web:02563becdc60bab98f0719',
  messagingSenderId: '1032501750236',
  projectId: 'giveme-5e950',
  authDomain: 'giveme-5e950.firebaseapp.com',
  databaseURL: 'https://giveme-5e950-default-rtdb.firebaseio.com',
  storageBucket: 'giveme-5e950.appspot.com',
  measurementId: 'G-QDVPGH1CD8',
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  console.log('[firebase-messaging-sw.js] Received background message:', message);
  const notificationTitle = message.notification?.title || 'GiveMe';
  const notificationOptions = {
    body: message.notification?.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});
