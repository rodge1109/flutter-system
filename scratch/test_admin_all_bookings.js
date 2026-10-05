const https = require('https');

const url = 'https://pickle-system.onrender.com/api/admin/all-bookings';

https.get(url, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log('Success:', parsed.success);
      if (parsed.bookings) {
        console.log('Total bookings returned by admin/all-bookings:', parsed.bookings.length);
        if (parsed.bookings.length > 0) {
          console.log('Sample booking dates & fields:', {
            id: parsed.bookings[0].id,
            service_type: parsed.bookings[0].service_type,
            court_name: parsed.bookings[0].court_name,
            preferred_date: parsed.bookings[0].preferred_date,
            appointment_date: parsed.bookings[0].appointment_date,
            created_at: parsed.bookings[0].created_at,
          });
        }
      } else {
        console.log('No bookings field in response:', parsed);
      }
    } catch (e) {
      console.error('Error parsing response:', e.message, 'Raw response:', data.substring(0, 200));
    }
  });
}).on('error', err => {
  console.error('Fetch error:', err.message);
});
