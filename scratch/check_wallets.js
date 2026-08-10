const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function check() {
  const wallets = await db.collection('wallets').get();
  console.log('--- WALLETS ---');
  wallets.forEach(d => console.log(d.id, d.data()));

  const txs = await db.collection('transactions').get();
  console.log('\n--- TRANSACTIONS ---');
  txs.forEach(d => console.log(d.id, d.data()));
  
  process.exit(0);
}

check();
