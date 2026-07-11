// Same two-layer idea as DOMAIN_STOPS in data/nepali_news_pipeline.py — strip
// grammatical noise so keyword search ranks on story-specific tokens instead
// of postpositions/pronouns/generic verbs that appear in every question.
const STOPWORDS = new Set([
  "र", "तर", "वा", "अनि", "कि", "पनि", "नै", "त", "नि",
  "को", "का", "की", "मा", "ले", "लाई", "बाट", "सँग", "साथ",
  "बीच", "भित्र", "बाहिर", "माथि", "तल", "अघि", "पछि",
  "सम्म", "देखि", "तिर", "निम्ति", "लागि",
  "छ", "छन्", "छु", "छौं", "थियो", "थिए", "थिइन्",
  "हो", "हुन्", "हुन", "हुने", "हुँदै", "हुनेछ",
  "गर्न", "गर्ने", "गर्छ", "गर्छन्", "गर्दै", "गर्नेछ",
  "गरेको", "गरेका", "गरिएको", "गरिएका", "गरेर", "गरी",
  "भएको", "भएका", "भएर", "भई", "भन्ने", "भनिएको",
  "रहेको", "रहेका", "रहेछ", "रहन्छ",
  "आएको", "गएको", "हुँदा", "छैन", "छैनन्",
  "यो", "त्यो", "यस", "उस", "यसको", "उसको",
  "उनी", "उनको", "उनले", "उनका", "उनलाई",
  "उहाँ", "उहाँको", "उहाँले",
  "हामी", "हाम्रो", "हामीलाई",
  "तपाई", "तपाईं", "तपाईंको", "तपाईंले",
  "हाम्रा", "हाम्री",
  "आज", "भोलि", "हिजो", "अब", "अहिले", "यहाँ",
  "के", "एक", "बारे", "सम्बन्धित", "अनुसार", "किन", "कसरी", "कहिले", "कहाँ",
  "भन्दा", "जस्तै", "जस्तो", "जसरी", "किनभने",
  "त्यसैले", "तसर्थ", "तथापि", "यद्यपि",
]);

// Extracts story-specific keywords from free text (a user's question).
// Mirrors specific_tokens() in the Python pipeline: keeps tokens longer than
// 4 chars that aren't in the stopword list. Short words (३-४ अक्षर) are
// almost always generic verbs/particles the stopword list doesn't catch
// ("भने", "गरे", "थियो"-adjacent forms) — matching on them is what let an
// unrelated Home Minister cluster outrank the actual answer during testing.
// Falls back to a looser >1-char filter only if the strict pass leaves
// nothing to search on (short questions).
const extractKeywords = (text) => {
  const cleaned = String(text || "").replace(/[।,.!?"':;\-–—()[\]{}/?]/g, " ");
  const tokens = cleaned.split(/\s+/).filter(Boolean);

  const strict = new Set();
  const loose = new Set();
  for (const t of tokens) {
    if (t.length <= 1 || STOPWORDS.has(t)) continue;
    loose.add(t);
    if (t.length > 4) strict.add(t);
  }

  return strict.size ? [...strict] : [...loose];
};

module.exports = { STOPWORDS, extractKeywords };
