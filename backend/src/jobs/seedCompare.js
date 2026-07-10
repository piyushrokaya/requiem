require('dotenv').config();
console.log('MONGO_URI:', process.env.MONGO_URI);
const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');

const connectDB = require('../config/db');
const ComparisonCluster = require('../models/comparision.model');

// Connect to MongoDB
connectDB();

const dataPath = path.join(__dirname, '../../data/clusters.json');
const seedData = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));

async function seedCompare() {
  try {
    // clear existing collection
    await ComparisonCluster.deleteMany({});
    console.log('Existing ComparisonCluster documents removed.');

    // Insert all clusters from JSON
    await ComparisonCluster.insertMany(seedData);
    console.log('ComparisonCluster collection seeded successfully.');

    mongoose.connection.close();
    console.log('MongoDB connection closed.');
  } catch (err) {
    console.error('Seeding error:', err);
    mongoose.connection.close();
  }
}

// Run the seeding function
seedCompare();