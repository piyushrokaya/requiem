

import os
import json
import requests
import pandas as pd


OUTPUT_CSV    = "data/all_articles_processed.csv"
CLUSTERS_JSON = "data/clusters.json"
OLLAMA_URL    = "http://localhost:11434/api/generate"
LLM_MODEL     = "gemma3:4b"


def llm(prompt: str, timeout: int = 60) -> str:
    try:
        r = requests.post(
            OLLAMA_URL,
            json={"model": LLM_MODEL, "prompt": prompt, "stream": False},
            timeout=timeout,
        )
        return r.json().get("response", "").strip()
    except Exception as e:
        return f"[LLM Error: {e}]"


def _build_block(articles: list[dict], body_chars: int = 800) -> str:
    return "\n\n".join(
        f"SOURCE: {a['source']}\nTITLE: {a['title']}\nBODY: {str(a.get('clean_text') or '')[:body_chars]}"
        for a in articles
    )


#  SUMMARY
#  Three levels — all designed to be read aloud via TTS:
#
#  one_liner     → 1 sentence, for list card / notification preview
#  short_summary → 2-3 sentences, simple Nepali, main TTS playback
#  key_points    → 3 numbered concrete facts, follow-up TTS
# ─────────────────────────────────────────────
def generate_summary(articles: list[dict]) -> dict:
    block = _build_block(articles)

    one_liner = llm(f"""एउटा वाक्यमा यो समाचारको सारांश नेपालीमा लेख्नुहोस्।
अधिकतम १५ शब्द। को, के, कहाँ — यी तीन कुरा समेट्नुहोस्।

{block}

एउटा वाक्य:""", timeout=30)

    short = llm(f"""तपाईं एक नेपाली समाचार विश्लेषक हुनुहुन्छ।
तलका समाचारहरू एउटै घटनाका बारेमा छन्।

{block}

निर्देशन:
- २-३ वाक्यमा मात्र सारांश लेख्नुहोस्
- सरल नेपाली भाषा प्रयोग गर्नुहोस् (अशिक्षित मानिसले पनि बुझ्ने गरी)
- के भयो, कसले गर्यो, कहाँ भयो — यी कुरा समेट्नुहोस्
- स्रोतको नाम उल्लेख नगर्नुहोस्

सारांश:""", timeout=45)

    facts = llm(f"""You are a Nepali news analyst.
Extract exactly 3 key facts from these articles.
Each fact = one short sentence in Nepali.
Include specific names, numbers, and places wherever available.
Do NOT write vague statements like "sources differ in tone".

{block}

Reply in this exact format, nothing else:
१. [तथ्य]
२. [तथ्य]
३. [तथ्य]""", timeout=45)

    return {
        "one_liner":     one_liner.strip(),
        "short_summary": short.strip(),
        "key_points":    facts.strip(),
    }

# ─────────────────────────────────────────────
#  MISSING INFO
#  Finds concrete facts, names, numbers, quotes present in one
#  source but absent from others. Purely factual — no tone analysis.
#
#  This is the core value of the app: showing what each outlet
#  chose to include or leave out, without editorialising about why.
# ─────────────────────────────────────────────
def find_missing_info(articles: list[dict]) -> str:
    if len(articles) < 2:
        return "केवल एक स्रोत — तुलना सम्भव छैन।"

    block = _build_block(articles)

    return llm(f"""You are a fact-checking journalist comparing Nepali news coverage of the same event.

{block}

Your task: Find specific information that appears in ONE source but is MISSING from the others.

ONLY report gaps that are concrete and verifiable:
✅ Names of people mentioned by one source but not others
✅ Specific numbers, dates, or amounts mentioned by one source but not others
✅ Direct quotes that only one source captured
✅ Specific locations or institutions only one source named
✅ Events or actions only one source described

❌ Do NOT mention tone differences
❌ Do NOT mention writing style differences
❌ Do NOT say things like "more detailed" or "less comprehensive"

Format strictly as:
- [SOURCE NAME] ले [SPECIFIC FACT] उल्लेख गर्यो, तर [OTHER SOURCE(S)] ले गरेनन्।

If there are no concrete factual gaps, write only:
सबै स्रोतले समान तथ्यहरू समेटेका छन्।

जानकारीको अन्तर:""", timeout=60)

# ─────────────────────────────────────────────
#  COVERAGE BREAKDOWN
#  Per-source factual summary — what did each outlet actually report?
#  No judgment on quality or tone. Just facts per source.
#  Designed to be read aloud: "Gorkhapatra covered X and Y.
#  Annapurna Post additionally covered Z."
# ─────────────────────────────────────────────
def coverage_breakdown(articles: list[dict]) -> str:
    if len(articles) < 2:
        return "केवल एक स्रोत।"

    block = _build_block(articles)

    return llm(f"""You are a neutral journalism analyst. For each source, list only the 
specific facts they included — people, numbers, quotes, locations, events.

{block}

For EACH source write a short bullet list:
Source: [name]
- [specific fact / name / number / quote]
- [specific fact / name / number / quote]
- [any detail unique to this source]

Do not judge quality. Do not comment on tone. Facts only.
Write in Nepali where possible.

स्रोतगत विवरण:""", timeout=60)


def analyse_cluster(articles: list[dict]) -> dict:
    base = {
        "cluster_id":  articles[0]["cluster_id"],
        "sources":     [a["source"] for a in articles],
        "titles":      [a["title"]  for a in articles],
        "category":    articles[0].get("category", "General"),
    }

    if len(articles) < 2:
        a = articles[0]
        return {
            **base,
            "one_liner":          a.get("title", ""),
            "short_summary":      str(a.get("clean_text") or "")[:200],
            "key_points":         "",
            "missing_info":       "केवल एक स्रोत।",
            "coverage_breakdown": "केवल एक स्रोत।",
        }

    print(f"     Generating summary...")
    summary_data = generate_summary(articles)

    print(f"     Finding missing info...")
    missing = find_missing_info(articles)

    print(f"     Coverage breakdown...")
    coverage = coverage_breakdown(articles)

    return {
        **base,
        **summary_data,
        "missing_info":       missing,
        "coverage_breakdown": coverage,
    }


def run_analysis() -> list[dict]:
    if not os.path.exists(OUTPUT_CSV):
        print(" No CSV found. Run nepali_news_pipeline.py first.")
        return []

    df = pd.read_csv(OUTPUT_CSV)

    n_trending = df.groupby("cluster_id").filter(
        lambda g: g["source"].nunique() >= 2
    )["cluster_id"].nunique()

    print(f" Analysing {n_trending} trending clusters...\n")

    results = []
    for cid, group in df.groupby("cluster_id"):
        if group["source"].nunique() < 2:
            continue

        articles = group.to_dict("records")
        sources  = group["source"].unique().tolist()
        print(f"  ── Cluster {cid} │ {len(articles)} articles │ {', '.join(sources)}")

        result = analyse_cluster(articles)
        results.append(result)
        print(f"     ✅ Done\n")

    os.makedirs("data", exist_ok=True)
    with open(CLUSTERS_JSON, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"{'='*50}")
    print(f" {len(results)} stories saved → {CLUSTERS_JSON}")
    print(f"{'='*50}\n")
    return results

# ─────────────────────────────────────────────
#  DISPLAY  (terminal verification)
# ─────────────────────────────────────────────
def display_results():
    if not os.path.exists(CLUSTERS_JSON):
        print("No results found. Run run_analysis() first.")
        return

    with open(CLUSTERS_JSON, encoding="utf-8") as f:
        clusters = json.load(f)

    if not clusters:
        print("No trending multi-source stories found.")
        return

    print(f"\n{'═'*62}")
    print(f"  {len(clusters)} TRENDING STORIES")
    print(f"{'═'*62}")

    for i, c in enumerate(clusters, 1):
        print(f"\n{'─'*62}")
        print(f"  #{i} [{c.get('category','?')}]  {' | '.join(c['sources'])}")
        print(f"{'─'*62}")
        print(f" ONE-LINER:\n   {c.get('one_liner','')}")
        print(f"\n SUMMARY:\n   {c.get('short_summary','')}")
        print(f"\n KEY POINTS:\n   {c.get('key_points','')}")
        print(f"\n COVERAGE BREAKDOWN:\n   {c.get('coverage_breakdown','')}")
        print(f"\n MISSING INFO:\n   {c.get('missing_info','')}")

    print(f"\n{'═'*62}\n")
if __name__ == "__main__":
    run_analysis()
    display_results()
