const express = require('express');
const router = express.Router();
const db = require('../models');
const auth = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');

// Dev-only: auto-admin middleware for browser-based admin page access
async function devAdmin(req, res, next) {
  if (process.env.NODE_ENV !== 'development') {
    return await auth(req, res, () => requireAdmin(req, res, next));
  }
  // In dev mode, use mock admin if no token
  if (!req.headers.authorization) {
    let [user] = await db.User.findOrCreate({
      where: { firebaseUid: 'dev-mock-uid' },
      defaults: { email: 'dev@example.com', displayName: 'Dev Admin', role: 'admin' },
    });
    req.user = user;
    return next();
  }
  await auth(req, res, () => requireAdmin(req, res, next));
}

// GET admin page (EJS view) — uses dev-friendly auth
router.get('/false-negatives/view', devAdmin, async (req, res) => {
  const { status } = req.query;
  const where = {};
  if (status && ['open', 'reviewed', 'resolved'].includes(status)) {
    where.status = status;
  }

  const reports = await db.FalseNegativeReport.findAll({
    where,
    include: [
      { model: db.User, as: 'user', attributes: ['id', 'email', 'displayName'] },
      { model: db.User, as: 'reviewer', attributes: ['id', 'email', 'displayName'] },
    ],
    order: [['occurredAt', 'DESC']],
  });

  const counts = {
    total: await db.FalseNegativeReport.count(),
    open: await db.FalseNegativeReport.count({ where: { status: 'open' } }),
    reviewed: await db.FalseNegativeReport.count({ where: { status: 'reviewed' } }),
    resolved: await db.FalseNegativeReport.count({ where: { status: 'resolved' } }),
  };

  const devToken = process.env.NODE_ENV === 'development' ? 'mock-token' : null;
  res.render('admin/false-negatives', {
    reports,
    currentStatus: status || '',
    counts,
    user: req.user,
    devToken,
  });
});

// JSON API routes — require auth + admin
router.get('/false-negatives', auth, requireAdmin, async (req, res) => {
  const { status, page = 1, limit = 20 } = req.query;
  const offset = (Math.max(1, Number(page)) - 1) * Number(limit);

  const where = {};
  if (status && ['open', 'reviewed', 'resolved'].includes(status)) {
    where.status = status;
  }

  const { rows, count } = await db.FalseNegativeReport.findAndCountAll({
    where,
    include: [
      { model: db.User, as: 'user', attributes: ['id', 'email', 'displayName'] },
      { model: db.User, as: 'reviewer', attributes: ['id', 'email', 'displayName'] },
    ],
    order: [['occurredAt', 'DESC']],
    offset,
    limit: Math.min(Number(limit), 100),
  });

  res.json({
    reports: rows,
    total: count,
    page: Number(page),
    pages: Math.ceil(count / Number(limit)),
  });
});

// PATCH — require auth + admin
router.patch('/false-negatives/:id', auth, requireAdmin, async (req, res) => {
  const { id } = req.params;
  const { status, adminNotes } = req.body;

  const report = await db.FalseNegativeReport.findByPk(id);
  if (!report) {
    return res.status(404).json({ error: 'Report not found' });
  }

  if (status && !['open', 'reviewed', 'resolved'].includes(status)) {
    return res.status(400).json({ error: 'Invalid status' });
  }

  report.status = status || report.status;
  report.adminNotes = adminNotes !== undefined ? adminNotes : report.adminNotes;
  report.reviewedBy = req.user.id;
  await report.save();

  res.json({ message: 'Report updated', report });
});

module.exports = router;
