const mongoose = require("mongoose");

const newsSchema = new mongoose.Schema(
  {
    source: String,
    title: String,
    description: String,
    link: String,
    content: String,
    category: String,
    sentiment: String,
  },
  { timestamps: true }
);

module.exports = mongoose.model("News", newsSchema);