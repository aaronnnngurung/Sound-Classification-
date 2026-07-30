const admin = require('../config/firebase');
const db = require('../models');

const auth = async (req, res, next) => {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid authorization header' });
  }

  const token = header.split(' ')[1];

  // Dev-mode bypass with mock-token
  if (process.env.NODE_ENV === 'development' && token === 'mock-token') {
    let [user] = await db.User.findOrCreate({
      where: { firebaseUid: 'dev-mock-uid' },
      defaults: { email: 'dev@example.com', displayName: 'Dev User', role: 'admin' },
    });
    req.user = user;
    return next();
  }

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const fbUid = decoded.uid;
    const email = decoded.email || '';

    // Find or create local user
    let [user] = await db.User.findOrCreate({
      where: { firebaseUid: fbUid },
      defaults: { email, displayName: decoded.name || email },
    });

    // Sync email if it changed
    if (user.email !== email) {
      user.email = email;
      await user.save();
    }

    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};

module.exports = auth;
