importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

const firebaseConfig = {
  apiKey: "AIzaSyD6ZYi8ZOHQ5WqUfe4M-0O8VMv5fH02xzI",
  appId: "1:1034503286496:web:3211fd556ba7b613e42a85",
  messagingSenderId: "1034503286496",
  projectId: "pickle-system",
  authDomain: "pickle-system.firebaseapp.com",
  storageBucket: "pickle-system.firebasestorage.app",
  measurementId: "G-C4TTPHWMCK"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
