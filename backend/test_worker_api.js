const axios = require('axios');

// Web API Key for agent-app-67bc4
const WEB_API_KEY = 'AIzaSyDYSqe4buWmmknIlEDeTpPn_5cTYemdI8E';

async function testCloudflareWorkerWithdraw() {
  try {
    const dummyEmail = `testuser_${Date.now()}@example.com`;
    const dummyPassword = 'password123';
    
    // 1. Sign up a dummy user using REST API to get an ID token immediately
    console.log(`Signing up dummy user: ${dummyEmail}`);
    const signUpRes = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${WEB_API_KEY}`,
      {
        email: dummyEmail,
        password: dummyPassword,
        returnSecureToken: true
      }
    );
    const idToken = signUpRes.data.idToken;

    // 2. Call the Cloudflare worker for WITHDRAWAL
    console.log('Calling Cloudflare worker API (/payments/withdraw)...');
    const workerRes = await axios.post(
      'https://agent-api.odulanaprogress.workers.dev/payments/withdraw',
      {
        amount: 500,
        accountNumber: '9038134862',
        bankCode: '100033'
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${idToken}`
        }
      }
    );
    
    console.log('✅ Worker Response SUCCESS:');
    console.log(JSON.stringify(workerRes.data, null, 2));

  } catch (error) {
    console.error('❌ Worker Response ERROR:');
    if (error.response) {
      console.error(JSON.stringify(error.response.data, null, 2));
    } else {
      console.error(error.message);
    }
  }
}

testCloudflareWorkerWithdraw();
