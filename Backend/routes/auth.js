const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const verifyToken = require('../middleware/verifyToken');

const users = [];

// ─── Manual Register ───────────────────────────────────────────
router.post('/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: 'All fields are required' });
    }

    const existingUser = users.find(u => u.email === email);
    if (existingUser) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    users.push({ name, email, password: hashedPassword, loginMethod: 'manual' });

    res.status(201).json({
      message: 'User registered successfully',
      user: { name, email }
    });

  } catch (err) {
    res.status(500).json({ message: 'Registration failed', error: err.message });
  }
});

// ─── Manual Login ──────────────────────────────────────────────
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const user = users.find(u => u.email === email);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (user.loginMethod !== 'manual') {
      return res.status(400).json({ message: `This account uses ${user.loginMethod} login` });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid password' });
    }

    res.json({
      message: 'Login successful',
      user: { name: user.name, email: user.email }
    });

  } catch (err) {
    res.status(500).json({ message: 'Login failed', error: err.message });
  }
});

// ─── Google Login ──────────────────────────────────────────────
router.post('/google-login', verifyToken, (req, res) => {
  try {
    const { uid, email, name, picture } = req.user;

    const existingUser = users.find(u => u.uid === uid);
    if (!existingUser) {
      users.push({ uid, email, name, photo: picture, loginMethod: 'google' });
    }

    res.json({
      message: 'Google login successful',
      user: { uid, email, name, photo: picture }
    });

  } catch (err) {
    res.status(500).json({ message: 'Google login failed', error: err.message });
  }
});

// ─── Facebook Login ────────────────────────────────────────────
router.post('/facebook-login', verifyToken, (req, res) => {
  try {
    const { uid, email, name, picture } = req.user;

    const existingUser = users.find(u => u.uid === uid);
    if (!existingUser) {
      users.push({ uid, email, name, photo: picture, loginMethod: 'facebook' });
    }

    res.json({
      message: 'Facebook login successful',
      user: { uid, email, name, photo: picture }
    });

  } catch (err) {
    res.status(500).json({ message: 'Facebook login failed', error: err.message });
  }
});

// ─── Phone Login ───────────────────────────────────────────────
router.post('/phone-login', verifyToken, (req, res) => {
  try {
    const { uid, phone_number, name } = req.user;

    const existingUser = users.find(u => u.uid === uid);
    if (!existingUser) {
      users.push({ uid, phone: phone_number, name, loginMethod: 'phone' });
    }

    res.json({
      message: 'Phone login successful',
      user: { uid, phone: phone_number, name }
    });

  } catch (err) {
    res.status(500).json({ message: 'Phone login failed', error: err.message });
  }
});

// ─── Get Current User (Token Check) ───────────────────────────
router.get('/me', verifyToken, (req, res) => {
  res.json({
    message: 'Token is valid',
    user: req.user
  });
});

module.exports = router;