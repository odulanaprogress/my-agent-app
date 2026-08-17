// OpenAI API key must NOT be exposed on the client.
// Route all AI calls through your Cloudflare Workers or backend endpoint.
// See: workers/src/handlers/ for where to add an AI proxy endpoint.

class AIConfig {
  // intentionally empty — no client-side API keys
  // If you need AI features, add a /ai/chat endpoint to the Workers
  // and call it with a Firebase token like all other secure endpoints.
}
