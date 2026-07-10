const express = require('express');
const router = express.Router();

const compareController = require('../controllers/comparision.controller');

router.get('/', compareController.getComparisons);

module.exports = router;