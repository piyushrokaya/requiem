const express = require("express");
const router = express.Router();
const controller = require("./qna.controller");

router.post("/ask", controller.askQuestion);

module.exports = router;
