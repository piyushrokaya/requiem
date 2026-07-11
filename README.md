# सङ्क्षेप (Sanksep)

**A Nepali-language news app that compares how different outlets cover the same story — and reads it all aloud.**

Most Nepali news apps show you one outlet's take on an event. Sanksep clusters the *same*
event as reported by multiple outlets and uses an LLM to surface:
- A neutral, combined summary of what happened
- How each outlet's **framing and tone** differs
- What one outlet reported that the others **left out**

It's also built accessibility-first: a fully voice-driven mode (Nepali speech-to-text /
text-to-speech) drives the entire app for users who can't or don't want to read a screen,
alongside a normal touch/text mode with adjustable text size, contrast, and dyslexia-friendly
spacing.

## Features

- 📰 **News feed** — top Nepali headlines aggregated from 12+ outlets, filterable by category
- 🔍 **तुलना (Compare)** — multi-source story clusters with summary, bias/framing analysis, and information-gap detection
- 💬 **सोधपुछ (Ask)** — ask free-form Nepali questions and get answers grounded in the actual news database (RAG), with cited sources
- 🎙️ **Voice-only mode** — a complete spoken navigation flow (listen to headlines, pick a category/story by voice, no screen reading required)
- ♿ **Accessibility controls** — text scale up to 200%, high contrast, dyslexia-friendly spacing, bold text, auto-read-aloud
- 📴 **Offline fallback** — cached news is shown automatically if the backend is unreachable

## How it works

```
RSS feeds (12 outlets)
        │
        ▼
Python pipeline ── scrapes, classifies, clusters same-story articles (no embeddings —
                   plain token-overlap clustering, tuned for Devanagari), then asks a
                   local LLM (Ollama / gemma3:4b) for summary + bias + gap analysis
        │
        ▼
Node.js / Express API ── serves news + comparisons, either straight from the pipeline's
                          output files or from Postgres (Neon) if configured
        │
        ▼
Flutter app ── News / Compare / Ask tabs, normal or voice-only interaction mode
                (Ask uses Gemini for on-demand, retrieval-augmented Q&A)
```

Full breakdown of every module, file, and design decision lives in [`docs/`](docs/) —
start at [`docs/README.md`](docs/README.md).

## Tech stack

| Layer | Tech |
|---|---|
| Mobile app | Flutter (Dart), Provider, `speech_to_text` + `flutter_tts` |
| Backend API | Node.js, Express |
| Database | Postgres (Neon) — optional, falls back to CSV/JSON files if unset |
| News pipeline | Python (feedparser, newspaper3k, pandas) |
| Clustering & cluster analysis | Local LLM via [Ollama](https://ollama.com) (`gemma3:4b`) |
| Q&A (RAG) | Google Gemini (`gemini-flash-lite-latest`) |

## Getting started

### Prerequisites

- Node.js
- Python 3 + `pip install -r backend/data/requirements.txt`
- [Ollama](https://ollama.com) with `gemma3:4b` pulled: `ollama pull gemma3:4b`
- Flutter SDK
- Optional: a [Neon](https://neon.tech) Postgres connection string, a [Gemini API key](https://aistudio.google.com/apikey), and `ngrok` (only needed to reach the backend from a physical phone)

### Backend

```bash
cd backend
npm install
cp .env.example .env      # fill in DATABASE_URL / GEMINI_API_KEY if you have them
npm start
```

### Frontend

```bash
cd app_end
flutter pub get
flutter run
```

On first launch, the app asks for the backend's address (QR scan or manual entry) —
emulators/simulators can just tap "skip" to use the built-in default.

Full setup details, environment variables, and common gotchas (Ollama not running,
ngrok tunnel URLs rotating, etc.) are in [`docs/setup.md`](docs/setup.md).

## Project structure

```
my_app/
├── app_end/           Flutter app (UI, voice assistant, accessibility)
├── backend/
│   ├── server.js      Express entry point
│   ├── src/           Routes, controllers, services, RAG, scheduler, DB schema
│   ├── scripts/       One-shot pipeline/refresh runners
│   └── data/          Python news pipeline + its output (CSV, clusters.json)
└── docs/              Full project documentation (start at docs/README.md)
```

## Documentation

| Doc | Covers |
|---|---|
| [docs/architecture.md](docs/architecture.md) | End-to-end data flow, design rationale |
| [docs/backend.md](docs/backend.md) | Express API, routes, services, Postgres/CSV fallback |
| [docs/data-pipeline.md](docs/data-pipeline.md) | The Python scrape/cluster/LLM-analysis pipeline |
| [docs/rag-qna.md](docs/rag-qna.md) | The Ask tab's retrieval-augmented Q&A system |
| [docs/frontend.md](docs/frontend.md) | Flutter app structure, screens, state, voice mode |
| [docs/setup.md](docs/setup.md) | Running everything locally + operational gotchas |
