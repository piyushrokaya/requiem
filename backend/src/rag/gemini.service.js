const axios = require("axios");

const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-flash-lite-latest";
const GEMINI_URL = (model) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

const askGemini = async (prompt) => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY not configured");
  }

  const { data } = await axios.post(
    GEMINI_URL(GEMINI_MODEL),
    {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.2, maxOutputTokens: 400 },
    },
    {
      headers: { "Content-Type": "application/json" },
      params: { key: apiKey },
      timeout: 20000,
    }
  );

  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error("Gemini returned no answer");
  }
  return text.trim();
};

module.exports = { askGemini };
