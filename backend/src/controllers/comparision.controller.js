const { getClusters } = require("../services/comparison.service");

exports.getComparisons = async (req, res) => {
  try {
    const page = Number.parseInt(req.query.page, 10) || 1;
    const limit = Number.parseInt(req.query.limit, 10) || 500;

    const safePage = page > 0 ? page : 1;
    const safeLimit = limit > 0 ? limit : 500;

    const clusters = await getClusters({ page: safePage, limit: safeLimit });
    res.json(clusters);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load clusters" });
  }
};
