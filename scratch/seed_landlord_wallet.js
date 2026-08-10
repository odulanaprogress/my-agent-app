const admin = require('firebase-admin');

// Initialize Firebase Admin with default ADC or service account if available
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'agent-app-67bc4'
  });
}

const db = admin.firestore();

async function updateLandlordWallet() {
  const landlordUid = 'FkJsK5soSZNkA1NTVzeqE9gkrN02';
  console.log(`Setting wallet balance for landlord ${landlordUid}...`);
  await db.collection('wallets').doc(landlordUid).set({
    uid: landlordUid,
    availableBalance: 499,
    balance: 499,
    escrowBalance: 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });
  console.log('Successfully set available balance to ₦499 for landlord!');
}

updateLandlordWallet().catch(err => {
  console.error('Error updating wallet:', err.message);
});
