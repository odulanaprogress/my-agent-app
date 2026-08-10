require('dotenv').config();
const express = require('express');
const cors = require('cors');

const bankRoutes = require('./routes/bankRoutes');
const escrowRoutes = require('./routes/escrowRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const webhookRoutes = require('./routes/webhookRoutes');
const errorHandler = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 5000;

// Enable CORS for mobile app & web clients
app.use(cors());

// Parse JSON Body
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request Logger
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  next();
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'online',
    service: 'Agent Real Estate Platform REST API',
    timestamp: new Date().toISOString(),
  });
});

// API Routes
app.use('/api/bank', bankRoutes);
app.use('/api/escrow', escrowRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/webhooks', webhookRoutes);

// 404 Route Handler
app.use('*', (req, res) => {
  res.status(404).json({ success: false, error: 'API Endpoint Not Found' });
});

// Error Handling Middleware
app.use(errorHandler);

// Start Express Server
app.listen(PORT, () => {
  console.log(`
  🚀 Agent Backend REST API Server is LIVE!
  ===========================================
  📡 Listening on Port: ${PORT}
  🔗 Local Endpoint: http://localhost:${PORT}/api/health
  🛡️ Environment: ${process.env.NODE_ENV || 'development'}
  ===========================================
  `);
});
