const express = require("express");
const router = express.Router();
const controller = require("../controllers/news.controller");

router.get("/", controller.listNews);
router.get("/categories", controller.listCategories);
router.post("/fetch", controller.fetchCSV);

module.exports = router;