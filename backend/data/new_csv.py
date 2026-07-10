import pandas as pd
import os

# --- Config ---
INPUT_FILE = "data/all_articles_processed.csv"  # Update this if your pipeline uses a different name
OUTPUT_FILE = "data/trending_clusters.csv"

if not os.path.exists(INPUT_FILE):
    print(f"❌ CSV not found at {INPUT_FILE}. Run the main script first!")
    exit()

df = pd.read_csv(INPUT_FILE)

# Sort by cluster_id so the output is organized
if "cluster_id" not in df.columns:
    print("❌ No 'cluster_id' column found. Has the clustering finished yet?")
    exit()

df = df.sort_values("cluster_id")

# Filter for clusters with more than 1 article
clusters = df.groupby("cluster_id").filter(lambda x: len(x) > 1)

print(f"📊 Found {len(clusters['cluster_id'].unique())} multi-source stories.\n")

# List to hold our structured data for the new CSV
csv_data = []

for cluster_id, group in clusters.groupby("cluster_id"):
    unique_sources = group["source"].nunique()
    
    print("\n" + "="*80)
    print(f"🧩 CLUSTER {cluster_id} | {len(group)} articles | Sources: {unique_sources}")
    print("="*80)

    for _, row in group.iterrows():
        cat = row.get('category', 'N/A')
        nepali_title = row.get('nepali_text', '') if pd.notna(row.get('nepali_text', '')) else ''
        
        # Terminal output
        print(f"  [{row['source']}] ({cat})")
        print(f"  EN: {row['title']}")
        if nepali_title:
            print(f"  NP: {nepali_title}")
        print("-" * 40)
        
        # Append to our list for the CSV
        csv_data.append({
            "Cluster_ID": cluster_id,
            "Total_Articles": len(group),
            "Unique_Sources": unique_sources,
            "Category": cat,
            "Source": row['source'],
            "Title": row['title'],
            "Nepali_Title": nepali_title,
            "URL": row.get('link', '')
        })

# --- Save to CSV ---
if csv_data:
    output_df = pd.DataFrame(csv_data)
    # Using utf-8-sig ensures Excel reads Nepali characters correctly
    output_df.to_csv(OUTPUT_FILE, index=False, encoding="utf-8-sig")
    print(f"\n✅ Successfully saved structured clusters to: {OUTPUT_FILE}")
else:
    print("\n⚠️ No multi-source clusters found to save.")