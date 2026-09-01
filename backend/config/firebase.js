const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// Supports three modes:
// 1. FIREBASE_SERVICE_ACCOUNT_JSON env var (Railway / any server deployment)
// 2. Application Default Credentials (Google Cloud environments)
// 3. Project-only mode (limited — no Auth/Firestore writes)
if (!admin.apps.length) {
  try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id,
      });
      console.log('✅ Firebase Admin SDK initialized with service account JSON');
    } else {
      admin.initializeApp();
      console.log('✅ Firebase Admin SDK initialized with Application Default Credentials');
    }
  } catch (err) {
    console.warn('⚠️ Firebase Admin SDK fallback init:', err.message);
    admin.initializeApp({
      projectId: 'agent-app-67bc4',
    });
  }
}

const db = admin.firestore();

module.exports = { admin, db };
