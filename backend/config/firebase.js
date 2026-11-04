const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function parseServiceAccount(rawInput) {
  if (!rawInput) return null;
  let raw = rawInput.trim();
  if ((raw.startsWith('"') && raw.endsWith('"')) || (raw.startsWith("'") && raw.endsWith("'"))) {
    try {
      raw = JSON.parse(raw);
    } catch (_) {
      raw = raw.slice(1, -1);
    }
  }
  const sa = typeof raw === 'string' ? JSON.parse(raw) : raw;
  if (sa && sa.private_key && typeof sa.private_key === 'string') {
    sa.private_key = sa.private_key.replace(/\\n/g, '\n');
  }
  return sa;
}

if (!admin.apps.length) {
  try {
    let serviceAccount = null;

    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      try {
        serviceAccount = parseServiceAccount(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
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

    if (serviceAccount && serviceAccount.private_key) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id || 'agent-app-67bc4',
      });
      console.log('✅ Firebase Admin SDK initialized with service account:', serviceAccount.client_email);
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
