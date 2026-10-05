const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('Grouping historical pickle_appointment rows into pickle_orders...');

    const res = await pool.query(`
      SELECT id, full_name, phone_number, email, service_type, preferred_date, preferred_time, total_amount, created_at, specialist_id, proof_of_payment
      FROM pickle_appointment
      WHERE status != 'cancelled' OR status IS NULL;
    `);

    const rawRows = res.rows;
    console.log(`Found ${rawRows.length} appointment slot rows.`);

    const grouped = {};
    for (const r of rawRows) {
      const player = (r.full_name || 'Player').trim();
      const court = (r.service_type || 'Court').trim();
      const date = r.preferred_date ? new Date(r.preferred_date).toISOString().split('T')[0] : '';
      const createdAt = r.created_at ? new Date(r.created_at).toISOString().substring(0, 16) : '';

      const key = `${player}_${court}_${date}_${createdAt}`;

      if (!grouped[key]) {
        grouped[key] = {
          ids: [],
          email: (r.email || 'customer@picklebook-ph.com').trim(),
          full_name: player,
          phone_number: r.phone_number || '',
          court_id: r.specialist_id || null,
          service_type: court,
          preferred_date: date,
          times: [],
          gross_amount: 0,
          payment_reference: r.proof_of_payment || null,
          created_at: r.created_at || new Date(),
        };
      }

      grouped[key].ids.push(r.id);
      grouped[key].gross_amount += parseFloat(r.total_amount || 0);
      if (!grouped[key].payment_reference && r.proof_of_payment) {
        grouped[key].payment_reference = r.proof_of_payment;
      }
      if (r.preferred_time) {
        grouped[key].times.push(r.preferred_time.trim());
      }
    }

    const orderEntries = Object.values(grouped);
    console.log(`Grouped into ${orderEntries.length} unique booking orders.`);

    let insertedCount = 0;
    for (let i = 0; i < orderEntries.length; i++) {
      const o = orderEntries[i];
      const hours = o.times.length > 0 ? o.times.length : 1;
      const fee = Math.ceil(hours / 5.0) * 15.0;
      const net = Math.max(0, o.gross_amount - fee);

      const orderNumber = `ORD-${o.ids[0] || i + 1}`;
      const preferredTimeStr = o.times.join(', ');

      await pool.query(
        `
        INSERT INTO pickle_orders (
          order_number, user_email, full_name, phone_number, court_id, service_type,
          preferred_date, preferred_time, total_hours, gross_amount, service_fee, net_amount,
          booking_type, payment_reference, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        ON CONFLICT (order_number) DO UPDATE SET payment_reference = EXCLUDED.payment_reference;
      `,
        [
          orderNumber,
          o.email,
          o.full_name,
          o.phone_number,
          o.court_id,
          o.service_type,
          o.preferred_date || '2026-10-04',
          preferredTimeStr,
          hours,
          o.gross_amount,
          fee,
          net,
          o.full_name.toLowerCase().includes('offline') ? 'owner_block' : 'player_online',
          o.payment_reference,
          o.created_at,
        ]
      );
      insertedCount++;
    }

    console.log(`Successfully populated ${insertedCount} order records into pickle_orders!`);
  } catch (err) {
    console.error('Error populating pickle_orders:', err);
  } finally {
    await pool.end();
  }
}

run();
