 const express = require('express');
const router = express.Router();
const verifyToken = require('../middleware/verifyToken');

const alerts = [];

router.post('/log', verifyToken, (req, res) => {
  const { soundType, confidence } = req.body;
  const userId = req.user.uid;

  if (!soundType) {
    return res.status(400).json({ message: 'soundType is required' });
  }

  const alert = {
    id: alerts.length + 1,
    userId,
    soundType,
    confidence,
    timestamp: new Date().toISOString()
  };

  alerts.push(alert);
  res.status(201).json({ message: 'Alert logged', alert });
});

router.get('/:userId', verifyToken, (req, res) => {
  const userAlerts = alerts.filter(a => a.userId === req.params.userId);

  if (userAlerts.length === 0) {
    return res.status(404).json({ message: 'No alerts found for this user' });
  }

  res.json(userAlerts);
});

module.exports = router;
