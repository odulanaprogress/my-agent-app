const axios = require('axios');

// Firebase Web API Key for agent-app-67bc4
const WEB_API_KEY = 'AIzaSyDYSqe4buWmmknIlEDeTpPn_5cTYemdI8E';

// Palmpay bank code in Nigeria = 999991
const PALMPAY_BANK_CODE = '999991';
const TARGET_ACCOUNT   = '9038134862';
const AMOUNT           = 300;

async function testWithdraw() {
  try {
    // Step 1: Sign up a temp test user to get a Firebase ID token
    const dummyEmail    = `testwithdraw_${Date.now()}@agentapp.com`;
    const dummyPassword = 'TestPass@123';

    console.log(`\n🔐 Creating temp test user: ${dummyEmail}`);
    const signUpRes = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${WEB_API_KEY}`,
      { email: dummyEmail, password: dummyPassword, returnSecureToken: true }
    );
    const idToken = signUpRes.data.idToken;
    const uid     = signUpRes.data.localId;
    console.log(`✅ Signed up. UID: ${uid}`);

    // Step 2: Call Cloudflare Worker withdraw endpoint
    console.log(`\n💸 Sending ₦${AMOUNT} to Palmpay account ${TARGET_ACCOUNT}...`);
    const workerRes = await axios.post(
      'https://agent-api.odulanaprogress.workers.dev/payments/withdraw',
      {
        amount:        AMOUNT,
        accountNumber: TARGET_ACCOUNT,
        bankCode:      PALMPAY_BANK_CODE,
      },
      {
        headers: {
          'Content-Type':  'application/json',
          'Authorization': `Bearer ${idToken}`,
        },
      }
    );

    console.log('\n✅ Withdrawal SUCCESS:');
    console.log(JSON.stringify(workerRes.data, null, 2));

  } catch (error) {
    console.error('\n❌ Withdrawal ERROR:');
    if (error.response) {
      console.error(JSON.stringify(error.response.data, null, 2));
    } else {
      console.error(error.message);
    }
  }
}

testWithdraw();
