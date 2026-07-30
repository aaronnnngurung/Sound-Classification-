const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH
  ? path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
  : null;

if (serviceAccountPath && require('fs').existsSync(serviceAccountPath)) {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
} else {
  // Fallback for development: allow unauthenticated requests via a mock
  console.warn('Firebase credentials not found — running with mock auth (dev only)');
  admin.initializeApp({ projectId: 'demo-project' });
}

module.exports = admin;
