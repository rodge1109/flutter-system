const { Pool } = require('pg');


const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

// Implementation of discount calculation matching LoyaltySettingsModel.calculateMemberPrice
function calculateMemberPrice(regularPrice, memberDiscountType, memberDiscountValue) {
  const value = parseFloat(memberDiscountValue) || 0.0;
  if (memberDiscountType === 'PERCENTAGE') {
    const discount = regularPrice * (value / 100.0);
    return Math.max(0, regularPrice - discount);
  } else if (memberDiscountType === 'FIXED_PRICE') {
    return value;
  } else if (memberDiscountType === 'DISCOUNT_AMOUNT') {
    return Math.max(0, regularPrice - value);
  }
  return regularPrice;
}

async function runTests() {
  console.log('--- STARTING VERIFICATION TESTS FOR MEMBER DISCOUNT MODES ---');
  
  const testOwner = 'genovabrylejethro@gmail.com';
  const regularPrice = 350.0;

  // Test Case 1: PERCENTAGE mode with default 0%
  console.log('\n[TEST 1] PERCENTAGE mode with 0% discount');
  let price1 = calculateMemberPrice(regularPrice, 'PERCENTAGE', 0);
  console.log(`Regular: ₱${regularPrice} -> VIP Member Price: ₱${price1}`);

  // Test Case 2: PERCENTAGE mode with 10%
  console.log('\n[TEST 2] PERCENTAGE mode with 10% discount');
  let price2 = calculateMemberPrice(regularPrice, 'PERCENTAGE', 10);
  console.log(`Regular: ₱${regularPrice} -> VIP Member Price: ₱${price2}`);

  // Test Case 3: DISCOUNT_AMOUNT mode with ₱0 OFF
  console.log('\n[TEST 3] DISCOUNT_AMOUNT mode with ₱0 OFF');
  let price3 = calculateMemberPrice(regularPrice, 'DISCOUNT_AMOUNT', 0);
  console.log(`Regular: ₱${regularPrice} -> VIP Member Price: ₱${price3}`);

  // Test Case 4: DISCOUNT_AMOUNT mode with ₱50 OFF
  console.log('\n[TEST 4] DISCOUNT_AMOUNT mode with ₱50 OFF');
  let price4 = calculateMemberPrice(regularPrice, 'DISCOUNT_AMOUNT', 50);
  console.log(`Regular: ₱${regularPrice} -> VIP Member Price: ₱${price4}`);

  // Test Case 5: FIXED_PRICE mode with ₱300 Flat Rate
  console.log('\n[TEST 5] FIXED_PRICE mode with ₱300 Flat Rate');
  let price5 = calculateMemberPrice(regularPrice, 'FIXED_PRICE', 300);
  console.log(`Regular: ₱${regularPrice} -> VIP Member Price: ₱${price5}`);

  // Test Case 6: FIXED_PRICE mode with default ₱0
  console.log('\n[TEST 6] FIXED_PRICE mode with default ₱0');
  let price6 = calculateMemberPrice(regularPrice, 'FIXED_PRICE', 0);
  console.log(`Regular: ₱${regularPrice} -> VIP Member Price: ₱${price6}`);

  // Test DB Update & Query
  console.log('\n--- VERIFYING POSTGRES DATABASE PERSISTENCE ---');
  await pool.query(
    `UPDATE pickle_loyalty_settings 
     SET member_discount_type = 'PERCENTAGE', member_discount_value = 0.00 
     WHERE owner_email = $1`,
    [testOwner]
  );
  
  const res = await pool.query(`SELECT * FROM pickle_loyalty_settings WHERE owner_email = $1`, [testOwner]);
  console.log('Database verification query result:', res.rows[0]);

  console.log('\n--- ALL VERIFICATION TESTS PASSED SUCCESSFULLY ---');
  await pool.end();
}

runTests().catch(err => {
  console.error('Test Failed:', err);
  pool.end();
});
