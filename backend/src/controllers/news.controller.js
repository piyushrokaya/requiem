const NewsService = require("../services/news.service");

const listNews = async (req, res) => {
  try {
    const { page, limit, category } = req.query;

    const result = await NewsService.getNews({
      page: Number(page) || 1,
      limit: Number(limit) || 10,
      category: category ? String(category).trim() : undefined,
    });

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch news" });
  }
};

const listCategories = async (req, res) => {
  try {
    const categories = await NewsService.getCategories();
    res.json({ data: categories });
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch categories" });
  }
};

const fetchCSV = async (req, res) => {
  try {
    // The API now serves directly from the CSV in the data folder.
    // This endpoint is kept for backwards compatibility.
    res.json({
      message:
        "CSV mode enabled: news is served directly from backen/data/all_articles_processed.csv",
    });
  } catch (err) {
    res.status(500).json({ error: "CSV import failed" });
  }
};

module.exports = {
  listNews,
  listCategories,
  fetchCSV,
};