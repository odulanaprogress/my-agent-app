const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  try {
    let serviceAccount = null;

    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      try {
        let raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON.trim();
        if (raw.startsWith('"') && raw.endsWith('"')) {
          raw = JSON.parse(raw);
        }
        serviceAccount = typeof raw === 'string' ? JSON.parse(raw) : raw;
        if (serviceAccount.private_key && typeof serviceAccount.private_key === 'string') {
          serviceAccount.private_key = serviceAccount.private_key.replace(/\\n/g, '\n');
        }
      } catch (parseErr) {
        console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON:', parseErr.message);
      }
    }

    if (!serviceAccount) {
      const localPath = path.join(__dirname, '../serviceAccountKey.json');
      if (fs.existsSync(localPath)) {
        try {
          serviceAccount = JSON.parse(fs.readFileSync(localPath, 'utf8'));
        } catch (_) {}
      }
    }

    if (serviceAccount) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id || 'agent-app-67bc4',
      });
      console.log('✅ Firebase Admin SDK initialized with service account');
    } else {
      admin.initializeApp({
        projectId: 'agent-app-67bc4',
      });
      console.log('⚠️ Firebase Admin SDK initialized in project-only fallback mode');
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
