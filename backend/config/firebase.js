const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function parseServiceAccount(rawInput) {
  if (!rawInput) return null;
  let s = String(rawInput).trim();
  const start = s.indexOf('{');
  const end = s.lastIndexOf('}');
  if (start !== -1 && end !== -1 && end > start) {
    s = s.substring(start, end + 1);
  }
  const sa = JSON.parse(s);
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

module.exports = { admin, db, parseServiceAccount };
