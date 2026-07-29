require('dotenv').config();

const express = require('express');
const cors = require('cors');

const {initializeApp, cert} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {getMessaging} = require('firebase-admin/messaging');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

const app = express();

app.use(cors());
app.use(express.json());

const emergencySounds = {
  siren: 'Emergency Siren',
  'emergency siren': 'Emergency Siren',
  glass_breaking: 'Glass Breaking',
  'glass breaking': 'Glass Breaking',
};

async function verifyFirebaseUser(req, res, next) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'Missing Firebase authentication token.',
    });
  }

  try {
    const idToken = header.substring('Bearer '.length);
    req.firebaseUser = await auth.verifyIdToken(idToken);
    next();
  } catch (error) {
    return res.status(401).json({
      error: 'Invalid Firebase authentication token.',
    });
  }
}

app.get('/health', (req, res) => {
  res.json({status: 'ok'});
});

app.post('/api/notify', verifyFirebaseUser, async (req, res) => {
  try {
    const {userId, sound, confidence, timestamp} = req.body;

    if (!userId || !sound) {
      return res.status(400).json({
        error: 'userId and sound are required.',
      });
    }

    if (req.firebaseUser.uid !== userId) {
      return res.status(403).json({
        error: 'You may only notify for your own detections.',
      });
    }

    const normalizedSound = emergencySounds[sound.trim().toLowerCase()];

    if (!normalizedSound) {
      return res.json({
        success: true,
        notificationSent: false,
        reason: 'Sound is not an emergency sound.',
      });
    }

    const linkDoc = await db.collection('guardian_links').doc(userId).get();

    if (!linkDoc.exists) {
      return res.json({
        success: true,
        notificationSent: false,
        reason: 'No Guardian connected.',
      });
    }

    const guardianUid = linkDoc.data().guardianUid;

    const [guardianDoc, deafUserDoc] = await Promise.all([
      db.collection('users').doc(guardianUid).get(),
      db.collection('users').doc(userId).get(),
    ]);

    const guardianToken = guardianDoc.data()?.fcmToken;
    const deafUserName = deafUserDoc.data()?.username || 'the Deaf User';

    if (!guardianToken) {
      return res.json({
        success: true,
        notificationSent: false,
        reason: 'Guardian has no FCM token yet.',
      });
    }

    const messageId = await messaging.send({
      token: guardianToken,
      notification: {
        title: 'Emergency Sound Detected',
        body: `${normalizedSound} detected on ${deafUserName}'s device.`,
      },
      data: {
        userId,
        sound: normalizedSound,
        confidence: String(confidence ?? ''),
        timestamp: String(timestamp ?? new Date().toISOString()),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'guardian_emergencies',
          sound: 'default',
        },
      },
    });

    return res.json({
      success: true,
      notificationSent: true,
      messageId,
    });
  } catch (error) {
    console.error('Notification error:', error);

    return res.status(500).json({
      error: 'Unable to process notification.',
    });
  }
});

const port = Number(process.env.PORT || 3000);

app.listen(port, () => {
  console.log(`Guardian notification backend running on port ${port}`);
});