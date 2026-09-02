const axios = require('axios');
const { HttpsProxyAgent } = require('https-proxy-agent');

const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;
const proxyUrl = process.env.PROXY_URL || process.env.FIXIE_URL;

const axiosConfig = {
  baseURL: 'https://api.flutterwave.com/v3',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${secretKey}`,
  },
  timeout: 15000,
};

// Route traffic through Static IP Proxy if the URL is provided
if (proxyUrl) {
  axiosConfig.httpsAgent = new HttpsProxyAgent(proxyUrl);
  console.log('🛡️ Flutterwave API traffic is routed through Static IP Proxy');
}

const flwClient = axios.create(axiosConfig);

module.exports = flwClient;
