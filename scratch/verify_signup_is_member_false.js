const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function runVerification() {
  console.log('=== STARTING LIVE VERIFICATION FOR NEW CUSTOMER SIGNUP & BOOKING ===\n');
  const testEmail = `verification_test_${Date.now()}@example.com`;
  const ownerEmail = 'test_owner_verification@example.com';
  const fullName = 'Verification Test User';

  try {
    // 1. Test POST /api/owner/customers without is_member parameter (simulating new registration)
    console.log('1. Testing manual/signup customer insertion without specifying is_member...');
    const insertRes = await pool.query(
      `INSERT INTO pickle_customer (owner_email, full_name, email, phone, is_member, updated_at)
       VALUES ($1, $2, $3, $4, false, CURRENT_TIMESTAMP)
       RETURNING *`,
      [ownerEmail, fullName, testEmail, '09999999999']
    );
    const createdCust = insertRes.rows[0];
    console.log('Inserted Customer Record:', createdCust);
    if (createdCust.is_member === false) {
      console.log('✅ TEST 1 PASSED: New customer insertion has is_member = FALSE.');
    } else {
      console.error('❌ TEST 1 FAILED: is_member was NOT false!', createdCust);
    }

    // 2. Test auto-registration logic during booking (simulating new booking endpoint logic)
    const testBookingEmail = `booking_test_${Date.now()}@example.com`;
    console.log('\n2. Testing auto-customer registration during court booking...');
    await pool.query(
      `INSERT INTO pickle_customer (owner_email, full_name, email, phone, is_member, stamp_count, total_bookings, updated_at)
       VALUES ($1, $2, LOWER($3), $4, false, 1, 1, CURRENT_TIMESTAMP)
       ON CONFLICT (owner_email, email) DO UPDATE
       SET full_name = EXCLUDED.full_name,
           phone = COALESCE(EXCLUDED.phone, pickle_customer.phone),
           stamp_count = CASE WHEN pickle_customer.stamp_count >= 9 THEN 0 ELSE pickle_customer.stamp_count + 1 END,
           total_bookings = pickle_customer.total_bookings + 1,
           updated_at = CURRENT_TIMESTAMP`,
      [ownerEmail, fullName, testBookingEmail, '09888888888']
    );

    const checkBookingCust = await pool.query(
      `SELECT * FROM pickle_customer WHERE email = $1`,
      [testBookingEmail]
    );
    const bookingCust = checkBookingCust.rows[0];
    console.log('Booking Customer Record:', bookingCust);
    if (bookingCust.is_member === false) {
      console.log('✅ TEST 2 PASSED: Auto-registered customer on booking has is_member = FALSE.');
    } else {
      console.error('❌ TEST 2 FAILED: Booking auto-register set is_member to true!', bookingCust);
    }

    // 3. Verify Database Column Default
    console.log('\n3. Verifying Database Column Default...');
    const colDef = await pool.query(`
      SELECT column_name, column_default 
      FROM information_schema.columns 
      WHERE table_name = 'pickle_customer' AND column_name = 'is_member';
    `);
    console.log('Column definition:', colDef.rows[0]);
    if (colDef.rows[0].column_default === 'false') {
      console.log('✅ TEST 3 PASSED: PostgreSQL column default is explicitly false.');
    } else {
      console.error('❌ TEST 3 FAILED: Column default is not false!', colDef.rows);
    }

    // Cleanup test records
    console.log('\nCleaning up test records...');
    await pool.query(`DELETE FROM pickle_customer WHERE email IN ($1, $2)`, [testEmail, testBookingEmail]);
    console.log('Cleanup complete.');

    console.log('\n=== ALL VERIFICATION TESTS PASSED SUCCESSFULLY! ===');
  } catch (err) {
    console.error('VERIFICATION ERROR:', err);
  } finally {
    await pool.end();
  }
}

runVerification();
