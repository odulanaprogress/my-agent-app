const axios = require('axios');

const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;

const flwClient = axios.create({
  baseURL: 'https://api.flutterwave.com/v3',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${secretKey}`,
  },
  timeout: 15000,
});

module.exports = flwClient;
