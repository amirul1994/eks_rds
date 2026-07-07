import React, { useEffect, useState } from 'react';

function App() {
  const [rootData, setRootData] = useState('Loading...');
  const [healthData, setHealthData] = useState('Loading...');

  useEffect(() => {
    // Requests go to Nginx (port 9000), which proxies them to Backend (port 8080)
    fetch('/api/')
      .then(res => res.text())
      .then(data => setRootData(data))
      .catch(err => setRootData('Error fetching data'));

    fetch('/api/health')
      .then(res => res.json())
      .then(data => setHealthData(data.status))
      .catch(err => setHealthData('Error fetching health'));
  }, []);

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h1>Frontend Application</h1>
      <p><strong>Backend (/):</strong> {rootData}</p>
      <p><strong>Backend (/health):</strong> {healthData}</p>
    </div>
  );
}

export default App;