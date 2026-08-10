const admin = require('firebase-admin');

// Initialize Firebase Admin SDK using Application Default Credentials or default app
if (!admin.apps.length) {
  try {
    admin.initializeApp();
    console.log('✅ Firebase Admin SDK initialized successfully');
  } catch (err) {
    console.warn('⚠️ Firebase Admin SDK default init notice (Using standalone firestore mode):', err.message);
    admin.initializeApp({
      projectId: 'agent-app-67bc4',
    });
  }
}

const db = admin.firestore();

module.exports = { admin, db };
