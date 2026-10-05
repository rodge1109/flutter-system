const https = require('https');

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

async function run() {
  try {
    console.log('Fetching raw-services to find all registered court owner emails...');
    const servicesRaw = await get('https://pickle-system.onrender.com/api/raw-services');
    const services = JSON.parse(servicesRaw);
    const ownerEmails = [...new Set(services.map(c => (c.owner_email || c.ownerEmail || '').trim()).filter(e => e.length > 0))];
    console.log('Found court owner emails:', ownerEmails);

    let allBookings = [];
    const seenIds = new Set();

    for (const email of ownerEmails) {
      try {
        const bRaw = await get(`https://pickle-system.onrender.com/api/owner/bookings/${encodeURIComponent(email)}`);
        const bData = JSON.parse(bRaw);
        if (bData.success && bData.bookings) {
          bData.bookings.forEach(b => {
            if (b.id && !seenIds.has(b.id)) {
              seenIds.add(b.id);
              allBookings.push(b);
            }
          });
        }
      } catch (e) {
        console.error(`Failed to fetch for ${email}:`, e.message);
      }
    }

    console.log(`\n=== TOTAL UNIQUE BOOKINGS ACROSS ALL VENUES: ${allBookings.length} ===`);
    if (allBookings.length > 0) {
      console.log('Sample bookings:');
      allBookings.slice(0, 5).forEach(b => {
        console.log({
          id: b.id,
          venue: b.service_type || b.court_name,
          player: b.full_name || b.player_name,
          amount: b.total_amount,
          date: b.appointment_date || b.preferred_date
        });
      });
    }
  } catch (e) {
    console.error('Error running test:', e);
  }
}

run();
