// RAG here is deliberately news-only: retrieval searches articles/clusters,
// so a greeting or "what can you do?" always returns zero DB matches and
// used to hard-fall-back to the "not enough info" message without Gemini
// ever running. These are common enough (voice assistants get "hello" and
// "who are you" constantly) that they deserve a real, on-brand answer
// instead of a canned failure message — and answering them here, before
// hitting Postgres/Gemini, is free and instant.
//
// Deliberately anchored (^...$) rather than substring-matched: "मौसम कस्तो
// छ?" (a weather question) contains "कस्तो छ" too, but is NOT small talk —
// anchoring keeps that distinction intact.
const GREETING_RE =
  /^(नमस्ते|नमस्कार|हाय|हेलो|हलो|hi|hello|hey|good\s*morning|good\s*afternoon|good\s*evening|गुड\s*मर्निङ|गुड\s*आफ्टरनुन|गुड\s*इभिनिङ|कस्तो\s*छ|कस्तो\s*हुनुहुन्छ|तपाईंलाई\s*कस्तो\s*छ|how\s*are\s*you)[\s!।.,?]*$/iu;

const META_RE =
  /(तिमी|तपाईं|तपाई)\s*(को|के)\s*(हो|हुनुहुन्छ)|(तिमी|तपाईं|तपाई).*(के\s*गर्न\s*सक्छौ|के\s*गर्न\s*सक्नुहुन्छ)|who\s*are\s*you|what\s*can\s*you\s*do|what\s*are\s*you/iu;

const THANKS_RE = /^(धन्यवाद|thanks|thank\s*you)[\s!।.,]*$/iu;

const GREETING_REPLY =
  "नमस्ते! म Sanksep हूँ, तपाईंको नेपाली समाचार सहायक। म हालका समाचार, स्रोतहरूबीचको तुलना, वा कुनै खास घटनाबारे प्रश्नको जवाफ दिन सक्छु। के सोध्न चाहनुहुन्छ?";

const META_REPLY =
  "म Sanksep हूँ — विभिन्न नेपाली समाचार स्रोतबाट समाचार जम्मा गरी सुनाउने र तुलना गर्ने सहायक। तपाईं मलाई कुनै समाचार घटना, स्रोतहरूबीचको भिन्नता, वा हालको ट्रेन्डिङ विषयबारे सोध्न सक्नुहुन्छ।";

const THANKS_REPLY =
  "तपाईंलाई पनि धन्यवाद! अरू कुनै समाचार वा तुलनाबारे सोध्न चाहनुहुन्छ भने भन्नुहोस्।";

// Returns a canned reply string if the question is small talk / about the
// assistant itself, or null if it should go through normal RAG retrieval.
const matchSmallTalk = (question) => {
  const q = String(question || "").trim();
  if (!q) return null;

  if (THANKS_RE.test(q)) return THANKS_REPLY;
  if (GREETING_RE.test(q)) return GREETING_REPLY;
  if (META_RE.test(q)) return META_REPLY;
  return null;
};

module.exports = { matchSmallTalk };
