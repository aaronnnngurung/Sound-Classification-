 const express = require('express');
const app = express();

const authRoutes = require('./routes/auth');
const alertRoutes = require('./routes/alerts');

app.use(express.json());

app.get('/', (req, res) => {
  res.send('Assistive Alert System API is running');
});

app.use('/api/auth', authRoutes);
app.use('/api/alerts', alertRoutes);

app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

app.use((err, req, res, next) => {
  console.error(err.message);
  res.status(500).json({ message: 'Something went wrong' });
});

app.listen(3000, () => {
  console.log('Server running on http://localhost:3000');
});
