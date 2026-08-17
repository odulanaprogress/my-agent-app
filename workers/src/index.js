/**
 * Agent App — Cloudflare Workers Secure API
 *
 * Routes:
 *   POST /bank/resolve              → resolve bank account name (auth required)
 *   POST /payments/virtual-account  → generate Flutterwave virtual account (auth required)
 *   POST /payments/verify           → verify Flutterwave payment (auth required)
 *   POST /payments/withdraw         → server-validated withdrawal (auth required)
 *   GET  /health                    → health check (no auth)
 *
 * All sensitive routes require a valid Firebase ID token in the
 * Authorization: Bearer <token> header.
 *
 * Environment Variables (set as secrets in Cloudflare dashboard):
 *   FLUTTERWAVE_SECRET_KEY  — Flutterwave live secret key
 *   FIREBASE_PROJECT_ID     — Firebase project ID
 *   ALLOWED_ORIGIN          — Your app's origin (e.g. https://my-agent-app-teal.vercel.app)
 */

import { handleBankResolve } from './handlers/bankResolve.js';
import { handleVirtualAccount } from './handlers/virtualAccount.js';
import { handleVerifyPayment } from './handlers/verifyPayment.js';
import { handleWithdraw } from './handlers/withdraw.js';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const method = request.method.toUpperCase();

    // ─── CORS ───────────────────────────────────────────────────────────────
    const allowedOrigin = env.ALLOWED_ORIGIN || '';
    const origin = request.headers.get('Origin') || '';

    const corsHeaders = {
      'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      'Access-Control-Max-Age': '86400',
    };

    // Only allow requests from the configured origin
    // Allow null origin for mobile app requests (no Origin header on native apps)
    const isAllowedOrigin = !origin || origin === allowedOrigin;
    if (isAllowedOrigin) {
      corsHeaders['Access-Control-Allow-Origin'] = origin || allowedOrigin;
    }

    // Handle CORS preflight
    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Block cross-origin requests from unknown origins (web only)
    if (origin && !isAllowedOrigin) {
      return new Response(
        JSON.stringify({ success: false, error: 'CORS: Origin not allowed' }),
        {
          status: 403,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // ─── ROUTING ────────────────────────────────────────────────────────────
    let response;

    try {
      // Health check
      if (method === 'GET' && url.pathname === '/health') {
        response = new Response(
          JSON.stringify({
            status: 'online',
            service: 'Agent App Secure API',
            timestamp: new Date().toISOString(),
            region: request.cf?.colo || 'unknown',
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      }

      // Bank account resolution
      else if (method === 'POST' && url.pathname === '/bank/resolve') {
        response = await handleBankResolve(request, env);
      }

      // Virtual account generation
      else if (method === 'POST' && url.pathname === '/payments/virtual-account') {
        response = await handleVirtualAccount(request, env);
      }

      // Payment verification
      else if (method === 'POST' && url.pathname === '/payments/verify') {
        response = await handleVerifyPayment(request, env);
      }

      // Withdrawal (server-validated)
      else if (method === 'POST' && url.pathname === '/payments/withdraw') {
        response = await handleWithdraw(request, env);
      }

      // 404 for everything else
      else {
        response = new Response(
          JSON.stringify({ success: false, error: 'Endpoint not found' }),
          { status: 404, headers: { 'Content-Type': 'application/json' } }
        );
      }
    } catch (err) {
      console.error('Unhandled Worker error:', err);
      response = new Response(
        JSON.stringify({ success: false, error: 'Internal server error' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Attach CORS headers to every response
    for (const [key, value] of Object.entries(corsHeaders)) {
      response.headers.set(key, value);
    }

    return response;
  },
};
