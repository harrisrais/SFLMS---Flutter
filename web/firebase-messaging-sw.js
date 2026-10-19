importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBZiUUS9igNtl7ZMj_JdNXMZ0U1ItG9Mck',
  authDomain: 'sflms-dfa70.firebaseapp.com',
  projectId: 'sflms-dfa70',
  storageBucket: 'sflms-dfa70.firebasestorage.app',
  messagingSenderId: '805954624299',
  appId: '1:805954624299:web:d1156e2af947158611c36e',
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'SFLMS update';
  const options = {
    body: payload.notification?.body || 'Your shipment has an update.',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});
