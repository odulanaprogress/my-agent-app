const admin = require('firebase-admin');
const path = require('path');

// Load environment variables if needed
require('dotenv').config({ path: path.resolve(__dirname, '../backend/.env') });

// Initialize Firebase Admin (assuming default application default credentials or explicit credentials in env)
// If you are running this locally, you must have GOOGLE_APPLICATION_CREDENTIALS set.
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function cleanupOldPins() {
  console.log('Starting data cleanup: Removing plain-text PINs from old transaction documents...');

  let batch = db.batch();
  let operationCount = 0;
  let totalCleaned = 0;

  try {
    const transactionsSnapshot = await db.collection('transactions').get();

    if (transactionsSnapshot.empty) {
      console.log('No transactions found in the database.');
      return;
    }

    for (const doc of transactionsSnapshot.docs) {
      const data = doc.data();

      // Check if the document has plain-text PINs
      if (data.tenantPin !== undefined || data.landlordPin !== undefined) {
        console.log(`Cleaning up transaction: ${doc.id}`);

        batch.update(doc.ref, {
          tenantPin: admin.firestore.FieldValue.delete(),
          landlordPin: admin.firestore.FieldValue.delete()
        });

        operationCount++;
        totalCleaned++;

        // Commit in batches of 400 (Firestore max is 500)
        if (operationCount >= 400) {
          await batch.commit();
          console.log(`Committed a batch of ${operationCount} updates...`);
          batch = db.batch(); // Create a new batch
          operationCount = 0;
        }
      }
    }

    // Commit any remaining updates in the final batch
    if (operationCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${operationCount} updates.`);
    }

    console.log(`✅ Data Cleanup Complete! Removed plain-text PINs from ${totalCleaned} documents.`);

  } catch (error) {
    console.error('Error during data cleanup:', error);
  }
}

cleanupOldPins()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
