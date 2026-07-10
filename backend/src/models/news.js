const mongoose = require("mongoose");

const newsSchema = new mongoose.Schema({
  source: { type: String, required: true },
  title: String,
  link: { type: String, unique: true },
  content: String,
  pubDate: Date,
  biasScore: Number,
  clusterId: String
}, { timestamps: true });

module.exports = mongoose.model("News", newsSchema);