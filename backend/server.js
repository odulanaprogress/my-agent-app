require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const bankRoutes = require('./routes/bankRoutes');
const escrowRoutes = require('./routes/escrowRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const webhookRoutes = require('./routes/webhookRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const errorHandler = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 5000;

// ── Security headers ─────────────────────────────────────────────────────────
app.use(helmet());

// ── CORS — restrict to known origins ────────────────────────────────────────
// Default origins: localhost for dev + the Flutter web app + the backend itself
const _defaultOrigins = [
  'http://localhost:3000',
  'http://localhost:5000',
  'https://my-agent-app-teal.vercel.app',
  'https://my-agent-app-backend.vercel.app',
];
const allowedOrigins = [
  ..._defaultOrigins,
  ...(process.env.ALLOWED_ORIGINS || '').split(',').filter(Boolean),
];

app.use(
  cors({
    origin: (origin, cb) => {
      // Allow requests with no origin (mobile apps, Postman, server-to-server)
      if (!origin || allowedOrigins.includes(origin)) {
        return cb(null, true);
      }
      return cb(new Error(`CORS: Origin ${origin} not allowed`));
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Accept'],
    credentials: true,
  })
);

// ── Body parsing ─────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Request logging ──────────────────────────────────────────────────────────
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  next();
});

// ── Global rate limit: 300 requests per 15 minutes ──────────────────────────
app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 300,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: 'Too many requests, please try again later.' },
  })
);

// ── Stricter rate limit on PIN verification (brute-force defence) ─────────
const pinRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many PIN attempts. Please try again in 15 minutes.' },
});

// ── Health check ─────────────────────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'online',
    service: 'Agent Real Estate Platform REST API',
    timestamp: new Date().toISOString(),
  });
});

// ── Outbound IP check (used to get static IP for Flutterwave whitelisting) ───
app.get('/api/outbound-ip', async (req, res) => {
  try {
    const response = await fetch('https://api.ipify.org?format=json');
    const data = await response.json();
    res.status(200).json({ outboundIp: data.ip, message: 'This is the IP to whitelist on Flutterwave' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch outbound IP', detail: err.message });
  }
});


// ── API Routes ───────────────────────────────────────────────────────────────
app.use('/api/bank', bankRoutes);
app.use('/api/escrow/verify-pin', pinRateLimiter); // tight limit on PIN endpoint
app.use('/api/escrow', escrowRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/webhooks', webhookRoutes);
app.use('/api/notify', notificationRoutes);

// ── 404 ──────────────────────────────────────────────────────────────────────
app.use('*', (req, res) => {
  res.status(404).json({ success: false, error: 'API Endpoint Not Found' });
});

// ── Error handling ───────────────────────────────────────────────────────────
app.use(errorHandler);

// ── Start server ─────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`
  🚀 Agent Backend REST API Server is LIVE!
  ===========================================
  📡 Listening on Port: ${PORT}
  🔗 Local Endpoint: http://localhost:${PORT}/api/health
  🛡️  Environment: ${process.env.NODE_ENV || 'development'}
  ===========================================
  `);
});
