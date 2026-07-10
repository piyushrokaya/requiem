const mongoose = require('mongoose');

const comparisonClusterSchema = new mongoose.Schema(
  {
    cluster_id: { type: Number, required: true, unique: true },

    sources: [{ type: String }],
    titles: [{ type: String }],

    category: String,

    one_liner: String,
    short_summary: String,
    key_points: String,
    missing_info: String,
    coverage_breakdown: String,
  },
  { timestamps: true }
);

module.exports = mongoose.model(
  'ComparisonCluster',
  comparisonClusterSchema
);