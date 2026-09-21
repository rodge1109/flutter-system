const http = require('https');

async function testMultiSlotBooking() {
  const times = ['8:00 PM', '9:00 PM', '10:00 PM', '11:00 PM'];
  let allSuccess = true;

  for (const time of times) {
    const data = JSON.stringify({
      serviceType: 'RED GOOSE',
      specialistId: '13',
      preferredDate: '2026-10-31',
      preferredTime: time,
      fullName: 'Lovely Bea Yocte Test',
      email: 'test_multi_slot_yocte@test.com',
      phoneNumber: '09123456789',
      paymentMethod: 'GCASH',
      totalAmount: 350,
      holdToken: 'hold_test'
    });

    await new Promise((resolve) => {
      const req = http.request('https://pickle-system.onrender.com/api/appointments', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data)
        }
      }, (res) => {
        let body = '';
        res.on('data', chunk => body += chunk);
        res.on('end', () => {
          console.log(`SLOT ${time} -> STATUS: ${res.statusCode}, BODY: ${body}`);
          if (res.statusCode !== 200 && res.statusCode !== 201) {
            allSuccess = false;
          }
          resolve();
        });
      });

      req.on('error', e => {
        console.error(e);
        allSuccess = false;
        resolve();
      });

      req.write(data);
      req.end();
    });
  }

  console.log('\nALL 4 SLOTS SUBMITTED cleanly:', allSuccess ? 'SUCCESS (TRUE)' : 'FAILED (FALSE)');
}

testMultiSlotBooking();
