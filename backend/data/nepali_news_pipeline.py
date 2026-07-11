
import os
import json
import time
import re
import threading
import feedparser
import requests
import pandas as pd
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor
from newspaper import Article


OUTPUT_CSV         = "data/all_articles_processed.csv"
CLUSTERS_JSON      = "data/clusters.json"
SEEN_URLS_FILE     = "data/seen_urls.txt"

OLLAMA_URL         = "http://localhost:11434/api/generate"
LLM_MODEL          = "gemma3:4b"

MIN_TOKEN_OVERLAP  = 2     
MAX_BODY_CHARS     = 3000
MAX_AI_WORKERS     = 3
FETCH_INTERVAL_SEC = 600

csv_lock = threading.Lock()

# ─────────────────────────────────────────────
#  STOPWORDS
#  Two layers:
#    1. General Nepali function words (grammatical noise)
#    2. Domain stops — words so common in the current news cycle
#       (election season) they carry zero story-level signal.
#       "निर्वाचन" appears in 80% of articles — useless for clustering.
# ─────────────────────────────────────────────
DOMAIN_STOPS = {
    # Conjunctions & particles
    "र", "तर", "वा", "अनि", "कि", "पनि", "नै", "त", "नि",

    # Postpositions / case markers
    "को", "का", "की", "मा", "ले", "लाई", "बाट", "सँग", "साथ",
    "बीच", "भित्र", "बाहिर", "माथि", "तल", "अघि", "पछि",
    "सम्म", "देखि", "तिर", "निम्ति", "लागि",

    # Common verbs (so generic they appear everywhere)
    "छ", "छन्", "छु", "छौं", "थियो", "थिए", "थिइन्",
    "हो", "हुन्", "हुन", "हुने", "हुँदै", "हुनेछ",
    "गर्न", "गर्ने", "गर्छ", "गर्छन्", "गर्दै", "गर्नेछ",
    "गरेको", "गरेका", "गरिएको", "गरिएका", "गरेर", "गरी",
    "भएको", "भएका", "भएर", "भई", "भन्ने", "भनिएको",
    "रहेको", "रहेका", "रहेछ", "रहन्छ",
    "आएको", "गएको", "हुँदा", "छैन", "छैनन्",

    # Pronouns
    "यो", "त्यो", "यस", "उस", "यसको", "उसको",
    "उनी", "उनको", "उनले", "उनका", "उनलाई",
    "उहाँ", "उहाँको", "उहाँले",
    "हामी", "हाम्रो", "हामीलाई",
    "तपाई", "तपाईंको", "तपाईंले",
    "हाम्रा", "हाम्री",

    # Time words (generic — every article has these)
    "आज", "भोलि", "हिजो", "अब", "अहिले", "यहाँ",

    # Filler / connective words
    "के", "एक", "बारे", "सम्बन्धित", "अनुसार",
    "भन्दा", "जस्तै", "जस्तो", "जसरी", "किनभने",
    "त्यसैले", "तसर्थ", "तथापि", "यद्यपि",
    "गरिएका", "भनिएका",    
}


SOURCES = [
    {"name": "Nagarik",        "url": "https://nagariknews.nagariknetwork.com/feed"},
    {"name": "OnlineKhabar",   "url": "https://www.onlinekhabar.com/feed"},
    {"name": "News of Nepal",  "url": "https://newsofnepal.com/feed/"},
    {"name": "OSNepal",        "url": "https://www.osnepal.com/feed"},
    {"name": "Nepali Post",    "url": "http://nepalipost.com/beta/feed"},
    {"name": "Artha Sarokar",  "url": "https://arthasarokar.com/feed"},
    {"name": "Onlinetv Nepal", "url": "https://onlinetvnepal.com/feed/"},
    {"name": "Setopati",       "url": "https://www.setopati.com/feed"},
    {"name": "News24nepal",    "url": "https://www.news24nepal.com/feed"},
    {"name": "Gorkhapatra",    "url": "https://gorkhapatraonline.com/rss"},
    {"name": "Thahakhabar",    "url": "https://www.thahakhabar.com/feed"},
    {"name": "Annapurna Post", "url": "https://annapurnapost.com/rss/"},
]


def specific_tokens(text: str) -> set:
    """
    Extract story-specific tokens from a title.
    Keeps tokens that are longer than 4 chars AND not in DOMAIN_STOPS.
    What passes: place names, people's names, numbers, specific nouns.
    What's filtered: grammar words, common election vocab.
    """
    cleaned = re.sub(r"[।,.!?\"':;\-–—()\[\]{}/]", " ", text)
    return {t for t in cleaned.split() if len(t) > 4 and t not in DOMAIN_STOPS}

def token_overlap(title1: str, title2: str) -> int:
    return len(specific_tokens(title1) & specific_tokens(title2))

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


VALID_CATEGORIES = ["Politics", "Sports", "Business", "Tech",
                    "Entertainment", "Health", "Crime", "General"]

def classify_category(title: str, body: str) -> str:
    prompt = f"""You are a Nepali news classifier. Pick EXACTLY ONE category.

Rules (apply in order, stop at first match):
- Hospital / doctor / disease / medicine / injury / death → Health
- Court / police / arrest / fraud / scam / rape / theft → Crime
- Game / goal / match / tournament / player / cricket → Sports
- App / phone / internet / software / AI / tech → Tech
- Stock / bank / economy / trade / budget / business → Business
- Actor / movie / celebrity / music / entertainment → Entertainment
- Election / government policy / party / parliament → Politics
- Anything else → General

TITLE: {title}
BODY: {body[:400]}

Reply with ONLY the single category word, nothing else."""

    raw = llm(prompt, timeout=30).strip().title()
    return raw if raw in VALID_CATEGORIES else "General"


def scrape_article(url: str, fallback: str) -> str:
    try:
        a = Article(url)
        a.download()
        a.parse()
        text = a.text.replace("\n", " ").strip()
    
        return text[:MAX_BODY_CHARS] if len(text) > 100 else fallback
    except:
        return fallback[:MAX_BODY_CHARS]

def process_article(article: dict) -> dict | None:
    try:
        body = scrape_article(article["link"], article["description"])
        article["clean_text"] = body
        article["category"]   = classify_category(article["title"], body)
        _save_article(article)
        save_seen_url(article["link"])
        return article
    except Exception as e:
        print(f" [{article.get('source')}] {e}")
        return None

def _save_article(article: dict):
    with csv_lock:
        os.makedirs("data", exist_ok=True)
        pd.DataFrame([article]).to_csv(
            OUTPUT_CSV, mode="a",
            header=not os.path.exists(OUTPUT_CSV),
            index=False, encoding="utf-8-sig",
        )

# ─────────────────────────────────────────────
#  CLUSTERING — pure token overlap, no embeddings
#
#  Why no embeddings?
#  Tested paraphrase-multilingual-MiniLM-L12-v2 on known same-story pairs:
#    Dhanusha candidate switch (same event, 2 sources) → sim: 0.28  ← noise
#    Ethanol policy (same event, 2 sources)            → sim: 0.61  ← unreliable
#    Upendra federalism quote (same event, 2 sources)  → sim: 0.70  ← borderline
#  Token overlap correctly identified all three. MiniLM doesn't understand
#  Devanagari script well enough for story-level matching.
#
#  Algorithm: Union-Find (path compression) — O(n²) comparisons,
#  but instantaneous in practice for <500 articles.
# ─────────────────────────────────────────────
def run_clustering():
    if not os.path.exists(OUTPUT_CSV):
        print(" No CSV yet.")
        return

    df = pd.read_csv(OUTPUT_CSV).reset_index(drop=True)
    if len(df) < 2:
        print("Not enough articles.")
        return

    print(f" Clustering {len(df)} articles...")

    titles = df["title"].tolist()
    n = len(titles)
    parent = list(range(n))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(x, y):
        parent[find(x)] = find(y)

    merged = 0
    for i in range(n):
        for j in range(i + 1, n):
            if token_overlap(titles[i], titles[j]) >= MIN_TOKEN_OVERLAP:
                union(i, j)
                merged += 1

    df["cluster_id"] = [find(i) for i in range(n)]

    # Re-index to consecutive integers
    id_map = {old: new for new, old in enumerate(sorted(df["cluster_id"].unique()))}
    df["cluster_id"] = df["cluster_id"].map(id_map)

    df = enforce_source_diversity(df)
    df.to_csv(OUTPUT_CSV, index=False, encoding="utf-8-sig")

    n_clusters = df["cluster_id"].nunique()
    n_trending = df.groupby("cluster_id").filter(
        lambda g: g["source"].nunique() >= 2
    )["cluster_id"].nunique()

    print(f"✅ {n_clusters} clusters | {n_trending} trending (2+ sources) | {merged} pairs linked")

def enforce_source_diversity(df: pd.DataFrame) -> pd.DataFrame:
    """
    Break clusters where all articles are from the same source.
    One outlet publishing 3 election articles ≠ trending story.
    Each such article becomes its own singleton cluster.
    """
    next_id = int(df["cluster_id"].max()) + 1
    rows = []
    for _, group in df.groupby("cluster_id"):
        if group["source"].nunique() == 1 and len(group) > 1:
            for _, row in group.iterrows():
                row = row.copy()
                row["cluster_id"] = next_id
                next_id += 1
                rows.append(row)
        else:
            rows.extend(group.to_dict("records"))
    return pd.DataFrame(rows)

def analyse_cluster(articles: list[dict]) -> dict:
    base = {
        "cluster_id": articles[0]["cluster_id"],
        "sources":    [a["source"] for a in articles],
        "titles":     [a["title"]  for a in articles],
        "category":   articles[0].get("category", "General"),
    }

    if len(articles) < 2:
        return {**base,
                "summary":       (articles[0].get("clean_text") if isinstance(articles[0].get("clean_text"), str) else "")[:300],
                "bias_analysis": "Single source — no comparison available.",
                "missing_info":  "N/A"}

    block = "\n\n".join(
        f"SOURCE: {a['source']}\nTITLE: {a['title']}\nBODY: {(a.get('clean_text') if isinstance(a.get('clean_text'), str) else '')[:600]}"
        for a in articles
    )

    summary = llm(f"""You are a Nepali news analyst. These articles cover the SAME event from different sources.
Write a neutral 3-5 sentence summary of what happened.

{block}

SUMMARY:""")

    bias = llm(f"""You are a media bias analyst. Compare how each source frames this story.
Focus on: tone, emphasis, whose quotes they use, what each source highlights or omits.
Write one concise paragraph per source.

{block}

BIAS & FRAMING:""")

    gaps = llm(f"""You are a journalism analyst. Find specific facts or perspectives that
one source mentions but others completely miss. List each gap clearly.

{block}

INFORMATION GAPS:""")

    return {**base, "summary": summary, "bias_analysis": bias, "missing_info": gaps}

def analyse_all_clusters() -> list[dict]:
    if not os.path.exists(OUTPUT_CSV):
        return []

    df = pd.read_csv(OUTPUT_CSV)
    results = []

    for cid, group in df.groupby("cluster_id"):
        if group["source"].nunique() < 2:
            continue
        articles = group.to_dict("records")
        print(f"  Cluster {cid}: {len(articles)} articles | {group['source'].nunique()} sources")
        results.append(analyse_cluster(articles))

    os.makedirs("data", exist_ok=True)
    with open(CLUSTERS_JSON, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"✅ {len(results)} trending stories → {CLUSTERS_JSON}")
    return results


def display_clusters():
    if not os.path.exists(CLUSTERS_JSON):
        print("No analysis found. Run a full cycle first.")
        return

    with open(CLUSTERS_JSON, encoding="utf-8") as f:
        clusters = json.load(f)

    if not clusters:
        print("No trending multi-source stories yet.")
        return

    print(f"\n{'═'*62}")
    print(f"  📰  {len(clusters)} TRENDING STORIES")
    print(f"{'═'*62}")

    for i, c in enumerate(clusters, 1):
        print(f"\n{'─'*62}")
        print(f"  #{i}  [{c.get('category','?')}]  {' | '.join(c['sources'])}")
        print(f"{'─'*62}")
        print(" TITLES:")
        for t in c["titles"]:
            print(f"   • {t}")
        print(f"\n SUMMARY:\n   {c['summary']}")
        print(f"\n BIAS & FRAMING:\n   {c['bias_analysis']}")
        print(f"\n INFORMATION GAPS:\n   {c['missing_info']}")

    print(f"\n{'═'*62}\n")


def debug_pair(title1: str, title2: str):
    """
    Check why two articles do or don't cluster. Call interactively.
    Example:
        debug_pair(
            "धनुषा–४ मा आजपाका उम्मेदवार महतो रास्वपा प्रवेश",
            "धनुषा ४ मा आम जनता पार्टीका उम्मेदवार रास्वपा प्रवेश"
        )
    """
    t1, t2 = specific_tokens(title1), specific_tokens(title2)
    shared = t1 & t2
    will_cluster = len(shared) >= MIN_TOKEN_OVERLAP
    print(f"\nTitle 1 tokens : {t1}")
    print(f"Title 2 tokens : {t2}")
    print(f"Shared ({len(shared)}): {shared}")
    print(f"→ {'✅ WILL cluster' if will_cluster else '❌ will NOT cluster'}\n")


def load_seen_urls() -> set:
    if os.path.exists(SEEN_URLS_FILE):
        with open(SEEN_URLS_FILE) as f:
            return set(f.read().splitlines())
    return set()

def save_seen_url(url: str):
    os.makedirs("data", exist_ok=True)
    with open(SEEN_URLS_FILE, "a") as f:
        f.write(url + "\n")

def fetch_new_articles() -> list[dict]:
    seen = load_seen_urls()
    collected = []
    for source in SOURCES:
        try:
            feed = feedparser.parse(source["url"])
            for entry in feed.entries[:10]:
                link = entry.get("link", "").strip()
                if not link or link in seen:
                    continue
                collected.append({
                    "source":      source["name"],
                    "title":       entry.get("title", "").strip(),
                    "description": entry.get("summary", "").strip(),
                    "link":        link,
                    "published":   entry.get("published", ""),
                    "category":    "Pending",
                    "clean_text":  "",
                    "cluster_id":  -1,
                })
        except Exception as e:
            print(f"  Feed error [{source['name']}]: {e}")
    print(f" {len(collected)} new articles fetched.")
    return collected


def run_cycle():
    articles = fetch_new_articles()
    if not articles:
        print(" No new articles.")
        return

    print(f"  Processing {len(articles)} articles ({MAX_AI_WORKERS} workers)...")
    with ThreadPoolExecutor(max_workers=MAX_AI_WORKERS) as ex:
        results = list(tqdm(ex.map(process_article, articles),
                            total=len(articles), desc="Processing"))

    ok = sum(1 for r in results if r is not None)
    print(f" {ok}/{len(articles)} processed.")

    run_clustering()
    print(" Analysing clusters...")
    analyse_all_clusters()
    display_clusters()

def main():
    print(" Nepali News Pipeline started.")
    while True:
        print(f"\n{'='*50}\n   {time.strftime('%Y-%m-%d %H:%M:%S')}\n{'='*50}")
        try:
            run_cycle()
        except Exception as e:
            print(f" Cycle error: {e}")
        print(f"⏱  Sleeping {FETCH_INTERVAL_SEC // 60} min...")
        time.sleep(FETCH_INTERVAL_SEC)

if __name__ == "__main__":
    main()
