importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB_902Yga1UzWexf-TCBJdcFYiLFcphS8U',
  appId: '1:346916174556:web:f2d981cd5084fa721c9219',
  messagingSenderId: '346916174556',
  projectId: 'queuenova-78ca8',
  authDomain: 'queuenova-78ca8.firebaseapp.com',
  storageBucket: 'queuenova-78ca8.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification || {};
  if (!title) return;
  self.registration.showNotification(title, {
    body,
    icon: 'icons/Icon-192.png',
  });
});
