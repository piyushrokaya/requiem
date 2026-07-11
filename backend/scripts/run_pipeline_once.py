"""Run the Nepali news pipeline for exactly ONE cycle, then exit.

The Node scheduler (src/jobs/refreshNews.job.js) calls this every 30 minutes.
The pipeline module itself (data/nepali_news_pipeline.py) exposes run_cycle()
for a single pass, but its main() loops forever (while True + sleep). If we
spawned the module directly it would never exit, so the Node side could never
run ingestion afterwards. This wrapper imports the module (which does NOT start
the loop, because that lives under `if __name__ == "__main__"`) and calls
run_cycle() a single time.

Must be executed with the backend root as the working directory, because the
pipeline reads/writes paths relative to it (e.g. "data/all_articles_processed.csv").
The scheduler already spawns us with cwd = backend root.
"""
import os
import sys

# Force UTF-8 on our streams too (belt-and-suspenders alongside PYTHONIOENCODING),
# so the pipeline's emoji/Devanagari prints never crash under Windows' cp1252.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Make the pipeline module importable (it lives in ../data relative to this file).
HERE = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(HERE, "..", "data")
sys.path.insert(0, DATA_DIR)

import nepali_news_pipeline as pipeline  # noqa: E402


def main():
    print("[run_once] starting single pipeline cycle...", flush=True)
    pipeline.run_cycle()
    print("[run_once] cycle complete.", flush=True)


if __name__ == "__main__":
    main()
