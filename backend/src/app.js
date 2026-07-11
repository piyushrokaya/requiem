const express = require("express");
const cors = require("cors");

const newsRoutes = require("./routes/news.routes");
const compareRoutes = require("./routes/comparision.routes");
const qnaRoutes = require("./rag/qna.routes");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    message: "CodeYatra News API",
    version: "1.0.0",
  });
});

app.use("/api/news", newsRoutes);
app.use("/api/compare", compareRoutes);
app.use("/api/qna", qnaRoutes);

module.exports = app;