const express = require('express');
const router = express.Router();
const db = require('../models');
const auth = require('../middleware/auth');

// POST /api/reports/false-negative
router.post('/false-negative', auth, async (req, res) => {
  const { soundType, description, occurredAt, deviceInfo } = req.body;

  if (!occurredAt) {
    return res.status(400).json({ error: 'occurredAt is required' });
  }

  const report = await db.FalseNegativeReport.create({
    userId: req.user.id,
    soundType: soundType || null,
    description: description || null,
    occurredAt: new Date(occurredAt),
    deviceInfo: deviceInfo || null,
  });

  res.status(201).json({ message: 'Report submitted', report });
});

module.exports = router;
