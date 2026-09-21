const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('Fixing block_bot_require_fullname trigger function to allow multi-slot bookings...');
    
    await pool.query(`
      CREATE OR REPLACE FUNCTION block_bot_require_fullname()
      RETURNS TRIGGER AS $$
      DECLARE
        extracted_name TEXT;
        recent_email_count INT;
      BEGIN
        -- Extract full_name directly from NEW.full_name
        extracted_name := NEW.full_name;

        -- RULE 1: FULL NAME IS REQUIRED (must not be NULL, empty, or under 3 characters)
        IF (extracted_name IS NULL OR LENGTH(TRIM(extracted_name)) < 3) THEN
          RAISE EXCEPTION 'Security Block: Full Name is required (minimum 3 characters).';
        END IF;

        -- RULE 2: EMAIL IS REQUIRED
        IF (NEW.email IS NULL OR TRIM(NEW.email) = '' OR NEW.email NOT LIKE '%@%.%') THEN
          RAISE EXCEPTION 'Security Block: Valid email address is required.';
        END IF;

        -- RULE 3: RATE LIMIT — Allow up to 20 slot entries per email per 10 seconds for multi-slot checkout
        SELECT COUNT(*) INTO recent_email_count
        FROM pickle_appointment
        WHERE email = NEW.email
          AND created_at > NOW() - INTERVAL '10 seconds';

        IF recent_email_count >= 20 THEN
          RAISE EXCEPTION 'Security Block: Exceeded maximum multi-slot booking limit per transaction.';
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    `);

    console.log('TRIGGER FUNCTION UPDATED SUCCESSFULLY TO ALLOW MULTI-SLOT BOOKINGS!');

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
