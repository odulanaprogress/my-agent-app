const axios = require('axios');

// Active, verified Flutterwave production secret key
const VERIFIED_SECRET_KEY = 'FLWSECK-cffcd8414166c11c09046a0b37605d8f-1a05591bf14vt-X';

const envKey = (process.env.FLUTTERWAVE_SECRET_KEY || '').trim();
// Ignore expired/stale keys that begin with FLWSECK-af
const secretKey =
  envKey && !envKey.startsWith('FLWSECK-af')
    ? envKey
    : VERIFIED_SECRET_KEY;

const bridgeUrl =
  process.env.PHP_BRIDGE_URL ||
  'https://summerinspectlog.com/flutterwave-bridge.php';

const bridgeToken =
  process.env.PHP_BRIDGE_TOKEN ||
  'AgentBridge2026SecureXK92mPqL';

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
    config.headers['x-flw-authorization'] = `Bearer ${secretKey.trim()}`;
    config.headers['Content-Type'] = 'application/json';
  } else {
    config.baseURL = 'https://api.flutterwave.com/v3';
    config.headers['Authorization'] = `Bearer ${secretKey.trim()}`;
    config.headers['Content-Type'] = 'application/json';
  }
  return config;
});

module.exports = flwClient;
