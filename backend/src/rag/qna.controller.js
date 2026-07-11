const RagService = require("./rag.service");
const GeminiService = require("./gemini.service");

const NO_CONTEXT_ANSWER =
  "यो बारेमा हामीसँग पर्याप्त जानकारी छैन। कृपया अर्को प्रश्न सोध्नुहोस्।";

const buildPrompt = ({ question, context }) => `तपाईं Sanksep एप्लिकेशनको नेपाली समाचार सहायक हुनुहुन्छ।
प्रयोगकर्ताले आवाज वा टाइप गरेर प्रश्न सोधेका छन्, र जवाफ पनि पढेर सुनाइनेछ (TTS)।

तलका समाचार खण्डहरू मात्र प्रयोग गरेर जवाफ दिनुहोस्। यसबाहेक अन्य ज्ञान प्रयोग नगर्नुहोस्।

नियमहरू:
- सरल, स्पष्ट नेपाली भाषामा जवाफ दिनुहोस् (कम शिक्षित मानिसले पनि बुझ्ने गरी)
- अधिकतम ३-४ वाक्य — जवाफ आवाजमा सुनाइनेछ, लामो नबनाउनुहोस्
- यदि तलका खण्डहरूमा जवाफ भेटिएन भने, ठ्याक्कै यही लेख्नुहोस्: "${NO_CONTEXT_ANSWER}"
- स्रोतको नाम प्रश्नमा नसोधिएसम्म नलेख्नुहोस्, तथ्यमा मात्र फोकस गर्नुहोस्
- अनुमान वा राजनीतिक/पक्षपाती टिप्पणी नगर्नुहोस्

समाचार खण्डहरू:
${context}

प्रश्न: ${question}

जवाफ:`;

const askQuestion = async (req, res) => {
  try {
    const { question, cluster_id } = req.body || {};

    if (!question || !String(question).trim()) {
      return res.status(400).json({ error: "question is required" });
    }

    const clusterId =
      cluster_id !== undefined && cluster_id !== null && cluster_id !== ""
        ? Number(cluster_id)
        : undefined;

    const { context, sources } = await RagService.retrieveContext({
      question: String(question).trim(),
      clusterId,
    });

    if (!context) {
      return res.json({ answer: NO_CONTEXT_ANSWER, sources: [] });
    }

    const prompt = buildPrompt({ question: String(question).trim(), context });
    const answer = await GeminiService.askGemini(prompt);

    res.json({ answer, sources });
  } catch (err) {
    console.error("[qna.controller] askQuestion failed:", err.message);
    res.status(500).json({ error: "Failed to answer question" });
  }
};

module.exports = { askQuestion };
