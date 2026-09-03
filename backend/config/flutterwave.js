const axios = require('axios');

const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;
const bridgeUrl = process.env.PHP_BRIDGE_URL;
const bridgeToken = process.env.PHP_BRIDGE_TOKEN;

const flwClient = axios.create({
  timeout: 15000,
});

// Interceptor to hijack the request and send it to the PHP bridge if configured
flwClient.interceptors.request.use((config) => {
  const targetUrl = `https://api.flutterwave.com/v3${config.url}`;
  
  if (bridgeUrl && bridgeToken) {
    config.baseURL = '';
    config.url = bridgeUrl;
    config.headers['x-bridge-token'] = bridgeToken;
    config.headers['x-target-url'] = targetUrl;
    config.headers['x-flw-authorization'] = `Bearer ${secretKey}`;
    config.headers['Content-Type'] = 'application/json';
  } else {
    config.baseURL = 'https://api.flutterwave.com/v3';
    config.headers['Authorization'] = `Bearer ${secretKey}`;
    config.headers['Content-Type'] = 'application/json';
  }
  return config;
});

module.exports = flwClient;
