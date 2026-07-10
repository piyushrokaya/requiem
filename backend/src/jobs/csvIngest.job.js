const fs = require("fs");
const csv = require("csv-parser");
const path = require("path");
const NewsService = require("../services/news.service");

const ingestCSV = async () => {
  const filePath = path.join(
    __dirname,
    "../../data/all_articles_processed.csv"
  );

  return new Promise((resolve, reject) => {
    const articles = [];

    fs.createReadStream(filePath)
      .pipe(
        csv({
          // Trim headers to remove BOM or whitespace
          mapHeaders: ({ header }) => header.trim(),
        })
      )
      .on("data", (row) => {
        const source = row.source?.replace(/^\uFEFF/, "") || "Unknown";

        articles.push({
          source,
          title: row.title,
          description: row.description,
          link: row.link,
          content: row.nepali_text,
          category: row.category,
          sentiment: row.sentiment,
        });
      })
      .on("end", async () => {
        try {
          await NewsService.bulkInsert(articles);
          console.log("CSV ingested successfully");
          resolve();
        } catch (err) {
          reject(err);
        }
      })
      .on("error", reject);
  });
};

module.exports = ingestCSV;