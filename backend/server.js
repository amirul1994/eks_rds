const express = require('express');
const cors = require('cors');
const app = express();
const PORT = 8080;

// Configure CORS to allow all origins and necessary headers
app.use(cors({
    origin: '*', // Allow requests from any machine
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// Parse JSON bodies (if needed in future)
app.use(express.json());

app.get('/', (req, res) => {
    res.send('Application is running');
});

app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

// Handle 404 for undefined routes to avoid default HTML error pages
app.use((req, res) => {
    res.status(404).json({ error: 'Route not found' });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Backend server is running on port ${PORT}`);
});
//