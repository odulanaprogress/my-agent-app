const axios = require('axios');
const { HttpsProxyAgent } = require('https-proxy-agent');

const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;
const fixieUrl = process.env.FIXIE_URL;

const axiosConfig = {
  baseURL: 'https://api.flutterwave.com/v3',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${secretKey}`,
  },
  timeout: 15000,
};

// Route traffic through Fixie Static IP Proxy if the URL is provided
if (fixieUrl) {
  axiosConfig.httpsAgent = new HttpsProxyAgent(fixieUrl);
  console.log('🛡️ Flutterwave API traffic is routed through Fixie Static IP');
}

const flwClient = axios.create(axiosConfig);

module.exports = flwClient;
