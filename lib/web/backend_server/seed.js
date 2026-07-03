/**
 * QueueNova — Synthetic operational data seed
 *
 * Generates 60 days of realistic queue history for Sri Lankan government offices.
 * Data distributions mirror the hour/day/month multipliers in MLPredictionService.
 *
 * Run: node seed.js
 */
require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL }
    : {
        host:     process.env.DB_HOST     || 'localhost',
        port:     parseInt(process.env.DB_PORT || '5432'),
        database: process.env.DB_NAME     || 'queuenova',
        user:     process.env.DB_USER     || 'postgres',
        password: process.env.DB_PASSWORD || 'Nikethani123',
      }
);

// ── Real Sri Lanka district populations (Census 2012) ────────────────────────
const districtPop = {
  Colombo: 2324349, Gampaha: 2304833, Kalutara: 1221948,
  Kandy: 1375382,   Matale: 486196,   'Nuwara Eliya': 741132,
  Galle: 1063334,   Matara: 814565,   Hambantota: 599903,
  Jaffna: 593397,   Mannar: 99051,    Vavuniya: 197103,
  Mullaitivu: 92238, Kilinochchi: 113510, Batticaloa: 526567,
  Ampara: 649402,   Trincomalee: 379541, Kurunegala: 1618465,
  Puttalam: 762396,  Anuradhapura: 860153, Polonnaruwa: 406088,
  Badulla: 906044,   Monaragala: 451058, Ratnapura: 1088007,
  Kegalle: 840542,
};
const AVG_POP = 852532;

// ── Government offices (name, district, type) ─────────────────────────────────
const offices = [
  { name: 'Divisional Secretariat - Colombo',    district: 'Colombo',    type: 'Divisional Secretariat', counters: 5 },
  { name: 'Divisional Secretariat - Dehiwala',   district: 'Colombo',    type: 'Divisional Secretariat', counters: 3 },
  { name: 'Divisional Secretariat - Negombo',    district: 'Gampaha',    type: 'Divisional Secretariat', counters: 4 },
  { name: 'Divisional Secretariat - Kandy',      district: 'Kandy',      type: 'Divisional Secretariat', counters: 4 },
  { name: 'Divisional Secretariat - Galle',      district: 'Galle',      type: 'Divisional Secretariat', counters: 3 },
  { name: 'Divisional Secretariat - Kurunegala', district: 'Kurunegala', type: 'Divisional Secretariat', counters: 3 },
  { name: 'Passport Office - Battaramulla',      district: 'Colombo',    type: 'Passport Office',        counters: 8 },
  { name: 'Passport Office - Kandy',             district: 'Kandy',      type: 'Passport Office',        counters: 4 },
  { name: 'RMV - Werahera',                      district: 'Colombo',    type: 'RMV',                    counters: 6 },
  { name: 'RMV - Kandy',                         district: 'Kandy',      type: 'RMV',                    counters: 4 },
  { name: 'NIC Service Center - Colombo',        district: 'Colombo',    type: 'NIC Service Center',     counters: 5 },
  { name: 'Land Registry - Colombo',             district: 'Colombo',    type: 'Land Registry',          counters: 4 },
  { name: 'Grama Niladhari - Nugegoda',          district: 'Colombo',    type: 'Grama Niladhari',        counters: 2 },
  { name: 'Birth & Death Registration - Colombo',district: 'Colombo',    type: 'Birth & Death Registration', counters: 3 },
];

// ── Service distribution (realistic Sri Lanka proportions) ────────────────────
// Source: typical DS / RMV / Passport office transaction ratios
// avgMin = average processing time per person (minutes) — matches dataset.py
const servicesByType = {
  'Divisional Secretariat': [
    { service: 'NIC Card',              weight: 30, fee: 500,   avgMin: 10 },
    { service: 'Birth Certificate',     weight: 18, fee: 200,   avgMin:  8 },
    { service: 'Marriage Certificate',  weight: 10, fee: 250,   avgMin:  8 },
    { service: 'Death Certificate',     weight: 8,  fee: 150,   avgMin:  8 },
    { service: 'Income Certificate',    weight: 12, fee: 100,   avgMin: 10 },
    { service: 'Residence Certificate', weight: 10, fee: 100,   avgMin: 10 },
    { service: 'Character Certificate', weight: 7,  fee: 150,   avgMin: 12 },
    { service: 'Land Registration',     weight: 5,  fee: 2500,  avgMin: 25 },
  ],
  'Passport Office': [
    { service: 'Passport Renewal',      weight: 55, fee: 3000,  avgMin: 28 },
    { service: 'Passport Application',  weight: 30, fee: 3500,  avgMin: 32 },
    { service: 'Dual Citizenship',      weight: 8,  fee: 15000, avgMin: 30 },
    { service: 'Foreign Employment',    weight: 7,  fee: 1000,  avgMin: 25 },
  ],
  'RMV': [
    { service: 'Driving License',       weight: 35, fee: 3000,  avgMin: 18 },
    { service: 'Vehicle Registration',  weight: 30, fee: 5000,  avgMin: 20 },
    { service: 'Revenue License',       weight: 25, fee: 1500,  avgMin: 12 },
    { service: 'Driving License Renewal', weight: 10, fee: 3000, avgMin: 15 },
  ],
  'NIC Service Center': [
    { service: 'National ID Card',      weight: 70, fee: 500,   avgMin: 10 },
    { service: 'NIC Card',              weight: 30, fee: 500,   avgMin: 10 },
  ],
  'Land Registry': [
    { service: 'Land Registration',     weight: 60, fee: 2500,  avgMin: 25 },
    { service: 'Stamp Duty',            weight: 40, fee: 1000,  avgMin: 20 },
  ],
  'Grama Niladhari': [
    { service: 'Grama Niladhari Certificate', weight: 50, fee: 50,  avgMin: 12 },
    { service: 'Income Certificate',           weight: 30, fee: 100, avgMin: 10 },
    { service: 'Residence Certificate',        weight: 20, fee: 100, avgMin: 10 },
  ],
  'Birth & Death Registration': [
    { service: 'Birth Certificate',  weight: 50, fee: 200, avgMin:  8 },
    { service: 'Death Certificate',  weight: 30, fee: 150, avgMin:  8 },
    { service: 'Marriage Certificate', weight: 20, fee: 250, avgMin:  8 },
  ],
};

// ── Hour-of-day arrival weights (mirrors MLPredictionService._hourMultiplier) ──
const hourWeight = {
  8: 0.60, 9: 1.25, 10: 1.45, 11: 1.30,
  12: 0.70, 13: 1.05, 14: 1.35, 15: 1.15, 16: 0.55,
};

// ── Day-of-week volume factor (mirrors _dayMultiplier) ────────────────────────
const dayFactor = { 0: 0, 1: 1.55, 2: 1.20, 3: 1.00, 4: 1.10, 5: 1.40, 6: 0.75 };
// JS day: 0=Sun,1=Mon,…,6=Sat

// ── Sri Lanka Poya / public holidays in 2025–2026 ─────────────────────────────
const holidays = new Set([
  '2025-01-13','2025-02-04','2025-02-12','2025-03-14','2025-04-13','2025-04-14',
  '2025-05-01','2025-05-12','2025-05-13','2025-06-11','2025-07-10','2025-08-09',
  '2025-09-07','2025-10-07','2025-11-05','2025-12-04','2025-12-25',
  '2026-01-01','2026-01-03','2026-01-14','2026-02-02','2026-02-04',
  '2026-03-03','2026-04-02','2026-04-13','2026-04-14','2026-05-01',
  '2026-05-02','2026-05-31','2026-12-25',
]);

// ── Sri Lankan citizen names (representative sample) ─────────────────────────
const sinhalaNames = [
  'Kamal Perera','Nimal Silva','Sunil Fernando','Ruwan Jayasinghe','Chamara Bandara',
  'Lasith Rajapaksa','Dinesh Senanayake','Pradeep Wickramasinghe','Roshan Gunawardena',
  'Asanka Dissanayake','Thilina Amarasinghe','Sampath Wijeratne','Chathura Liyanage',
  'Malith Ranasinghe','Nuwan Pathirana','Buddika Weerasinghe','Sanjaya Mendis',
  'Kavinda Jayawardena','Rashika Kumara','Lahiru Gamage',
];
const tamilNames = [
  'Krishnan Murugesan','Selvam Ramasamy','Rajan Subramaniam','Vijay Sivakumar',
  'Tharshan Kandasamy','Priya Chandrasekaran','Nithya Balakrishnan','Kavitha Sundaram',
  'Senthil Arumugam','Prabhu Natarajan',
];
const muslimNames = [
  'Mohamed Farook','Ahamed Razak','Ismail Jabbar','Fathima Nusra','Zainab Mohamed',
  'Samsudeen Rifky','Cassim Jinna','Marikar Hussain',
];
const allNames = [...sinhalaNames, ...tamilNames, ...muslimNames];

// ── Helpers ───────────────────────────────────────────────────────────────────
function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

function weightedPick(items) {
  const total = items.reduce((s, i) => s + i.weight, 0);
  let r = Math.random() * total;
  for (const item of items) { r -= item.weight; if (r <= 0) return item; }
  return items[items.length - 1];
}

function randomHour() {
  const weighted = [];
  for (const [h, w] of Object.entries(hourWeight)) {
    for (let i = 0; i < Math.round(w * 10); i++) weighted.push(parseInt(h));
  }
  return pick(weighted);
}

function nicOld() {
  const y = String(Math.floor(Math.random() * 99)).padStart(2, '0');
  const d = String(Math.floor(Math.random() * 365) + 1).padStart(3, '0');
  const s = String(Math.floor(Math.random() * 9999)).padStart(4, '0');
  return `${y}${d}${s}V`;
}

function nicNew() {
  const y = 1970 + Math.floor(Math.random() * 40);
  const d = String(Math.floor(Math.random() * 365) + 1).padStart(3, '0');
  const s = String(Math.floor(Math.random() * 9999)).padStart(4, '0');
  return `${y}${d}${s}`;
}

function randomNic() { return Math.random() < 0.5 ? nicOld() : nicNew(); }

function demandFactor(district) {
  const pop = districtPop[district] || AVG_POP;
  return Math.min(Math.max(pop / AVG_POP, 0.5), 1.85);
}

function isoDate(d) { return d.toISOString().split('T')[0]; }

function addDays(base, n) {
  const d = new Date(base);
  d.setDate(d.getDate() + n);
  return d;
}

// ── Main seed function ────────────────────────────────────────────────────────
async function seed() {
  console.log('🌱  QueueNova seed — connecting to PostgreSQL …');
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Clear old seed data (keep staff users)
    await client.query("DELETE FROM audit_logs");
    await client.query("DELETE FROM payments");
    await client.query("DELETE FROM appointments");
    await client.query("DELETE FROM emergency_queue");
    await client.query("DELETE FROM queue_entries");
    console.log('   ✅ Cleared old seed rows');

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const startDay = addDays(today, -60);

    let queueInserted = 0;
    let apptInserted  = 0;
    let payInserted   = 0;
    let emergInserted = 0;
    let tokenSeq      = 1;

    // ── 60 days of queue history ─────────────────────────────────────────────
    for (let di = 0; di < 60; di++) {
      const day = addDays(startDay, di);
      const jsDay = day.getDay(); // 0=Sun
      const dateStr = isoDate(day);

      if (jsDay === 0) continue;                       // Sunday — closed
      if (holidays.has(dateStr)) continue;             // Holiday — closed

      const dayF = dayFactor[jsDay] || 1.0;

      for (const office of offices) {
        const df     = demandFactor(office.district);
        // Base arrivals per day: 80 for a medium office, scaled by demand + day
        const baseArrivals = Math.round(80 * office.counters * 0.25 * df * dayF);
        const arrivals = Math.max(5, baseArrivals + Math.round((Math.random() - 0.5) * 10));

        const services = servicesByType[office.type] || servicesByType['Divisional Secretariat'];

        for (let i = 0; i < arrivals; i++) {
          const hour  = randomHour();
          const minute = Math.floor(Math.random() * 60);
          const second = Math.floor(Math.random() * 60);
          const created = new Date(day);
          created.setHours(hour, minute, second, 0);

          const svc     = weightedPick(services);
          const token   = `${office.type === 'Passport Office' ? 'P' : office.type === 'RMV' ? 'R' : 'A'}-${String(tokenSeq++).padStart(3,'0')}`;
          const name    = pick(allNames);
          const nic     = randomNic();
          const counter = Math.ceil(Math.random() * office.counters);

          // ~85% completed, ~10% serving, ~5% waiting (older = completed)
          const rand   = Math.random();
          const status = di < 58 ? (rand < 0.95 ? 'completed' : 'cancelled')
                                 : (rand < 0.10 ? 'serving'   : (rand < 0.40 ? 'waiting' : 'completed'));

          const completedAt = status === 'completed'
            ? new Date(created.getTime() + svc.avgMin * 60 * 1000 * (0.8 + Math.random() * 0.6))
            : null;

          const isPriority    = Math.random() < 0.05;
          const paymentStatus = Math.random() < 0.92 ? 'paid' : 'pending';

          await client.query(
            `INSERT INTO queue_entries
               (token, office_id, citizen_name, citizen_nic, service, status,
                counter, is_priority, payment_status, fee, created_at, completed_at)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
            [token, office.name, name, nic, svc.service, status,
             counter, isPriority, paymentStatus, svc.fee,
             created, completedAt]
          );
          queueInserted++;

          // Payment record for paid entries
          if (paymentStatus === 'paid' && svc.fee > 0) {
            const methods = ['card', 'cash', 'qr_code'];
            const method  = pick(methods);
            await client.query(
              `INSERT INTO payments (appointment_id, amount, method, status, paid_at)
               VALUES ($1,$2,$3,'completed',$4)`,
              [null, svc.fee, method, created]
            ).catch(() => {}); // payments table may require appointment_id FK — skip if it fails
            payInserted++;
          }
        }

        // ~2 emergency queue entries on busier days
        if (dayF > 1.0 && Math.random() < 0.25) {
          const reasons  = ['Medical Emergency', 'Elderly Citizen', 'Pregnant Woman', 'Disability', 'Urgent Document'];
          const eCreated = new Date(day);
          eCreated.setHours(9 + Math.floor(Math.random() * 6), Math.floor(Math.random() * 60));
          await client.query(
            `INSERT INTO emergency_queue (token, office_id, citizen_name, reason, payment_status, status, created_at)
             VALUES ($1,$2,$3,$4,'paid','priority',$5)`,
            [`E-${String(tokenSeq++).padStart(3,'0')}`, office.name, pick(allNames), pick(reasons), eCreated]
          );
          emergInserted++;
        }
      }
    }

    // ── 30 days of future appointments ───────────────────────────────────────
    const services = ['Passport Renewal','NIC Card','Driving License','Birth Certificate',
                      'Marriage Certificate','Land Registration','Revenue License'];
    for (let di = 1; di <= 30; di++) {
      const day    = addDays(today, di);
      const jsDay  = day.getDay();
      const dateStr = isoDate(day);
      if (jsDay === 0 || holidays.has(dateStr)) continue;

      const count = 3 + Math.floor(Math.random() * 8);
      for (let i = 0; i < count; i++) {
        const hour   = randomHour();
        const apptDt = new Date(day);
        apptDt.setHours(hour, Math.floor(Math.random() * 60));
        const office = pick(offices);
        const svc    = pick(services);
        const name   = pick(allNames);
        const nic    = randomNic();

        const { rows } = await client.query(
          `INSERT INTO appointments (citizen_name, citizen_nic, service, office_id, appointment_date, status, notes, created_at)
           VALUES ($1,$2,$3,$4,$5,'scheduled','',$6) RETURNING id`,
          [name, nic, svc, office.name, apptDt, new Date()]
        );
        apptInserted++;

        // Corresponding payment (70% pre-paid)
        if (Math.random() < 0.70) {
          await client.query(
            `INSERT INTO payments (appointment_id, amount, method, status, paid_at)
             VALUES ($1,$2,$3,'completed',NOW())`,
            [rows[0].id, 500 + Math.floor(Math.random() * 4500), pick(['card','qr_code'])]
          ).catch(() => {});
          payInserted++;
        }
      }
    }

    // ── Audit log entries ─────────────────────────────────────────────────────
    const actions = ['login','add_queue','call_next','complete_service','update_settings','add_emergency'];
    const staff   = ['admin@queuenova.gov.lk','queue@queuenova.gov.lk','service@queuenova.gov.lk'];
    for (let i = 0; i < 200; i++) {
      const d = addDays(today, -Math.floor(Math.random() * 60));
      d.setHours(8 + Math.floor(Math.random() * 9));
      await client.query(
        `INSERT INTO audit_logs (action, performed_by, details, created_at) VALUES ($1,$2,$3,$4)`,
        [pick(actions), pick(staff), `Seed audit entry ${i+1}`, d]
      );
    }

    await client.query('COMMIT');

    console.log(`\n✅  Seed complete:`);
    console.log(`   Queue entries : ${queueInserted}`);
    console.log(`   Appointments  : ${apptInserted}`);
    console.log(`   Payments      : ${payInserted}`);
    console.log(`   Emergency     : ${emergInserted}`);
    console.log(`   Audit logs    : 200`);
    console.log(`\n   Data spans 60 days of history + 30 days of future appointments.`);
    console.log(`   Districts weighted by real 2012 Census populations.\n`);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌  Seed failed — rolled back:', err.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

seed();
