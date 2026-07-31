require("dotenv").config();
const axios = require("axios");

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

async function test() {
  try {
    const payload = {
      app_id: ONESIGNAL_APP_ID,
      target_channel: "push",
      include_external_user_ids: ["wKWdNI46p9dvB4BxWAevaWSrS8p2"],
      include_aliases: {
        external_id: ["wKWdNI46p9dvB4BxWAevaWSrS8p2"]
      },
      headings: { en: `New message from Test` },
      contents: { en: "Hello from test, both aliases and external" },
    };

    console.log("Sending payload...");
    const response = await axios.post("https://onesignal.com/api/v1/notifications", payload, {
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
    });

    console.log("Success:", response.data);
  } catch (error) {
    console.error("Error:", error.response ? JSON.stringify(error.response.data, null, 2) : error.message);
  }
}

test();
