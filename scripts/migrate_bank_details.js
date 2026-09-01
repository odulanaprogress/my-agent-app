const path = require('path');
const admin = require(path.resolve(__dirname, '../backend/node_modules/firebase-admin'));
const fs = require('fs');

require(path.resolve(__dirname, '../backend/node_modules/dotenv')).config({ path: path.resolve(__dirname, '../backend/.env') });

if (!admin.apps.length) {
  const localSaPath = 'C:/Users/PROGEETECHNOLOGY/Downloads/agent-app-67bc4-firebase-adminsdk-fbsvc-d6fc606cb0.json';
  if (fs.existsSync(localSaPath)) {
    const serviceAccount = require(localSaPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else {
    admin.initializeApp({
      projectId: 'agent-app-67bc4',
    });
  }
}

const db = admin.firestore();

async function migrateBankDetails() {
  console.log('Starting migration: moving bankDetails out of /users into /bank_accounts...');

  const usersSnapshot = await db.collection('users').get();

  if (usersSnapshot.empty) {
    console.log('No users found.');
    return;
  }

  let batch = db.batch();
  let operationCount = 0;
  let migrated = 0;

  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    if (!data.bankDetails) continue;

    console.log(`Migrating bank details for user: ${doc.id}`);

    const bankAccountRef = db.collection('bank_accounts').doc(doc.id);
    batch.set(bankAccountRef, {
      ...data.bankDetails,
      uid: doc.id,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    batch.update(doc.ref, {
      bankDetails: admin.firestore.FieldValue.delete(),
    });

    operationCount += 2;
    migrated++;

    if (operationCount >= 400) {
      await batch.commit();
      console.log(`Committed batch of ${operationCount} operations.`);
      batch = db.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    await batch.commit();
    console.log(`Committed final batch of ${operationCount} operations.`);
  }

  console.log(`Migration complete. Moved bank details for ${migrated} user(s).`);
}

migrateBankDetails()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
