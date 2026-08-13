const bcrypt = require('bcryptjs');
const { Client } = require('pg');

async function main() {
  const client = new Client({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'ca2_test',
    user: process.env.DB_USER || 'ca2app',
    password: process.env.DB_PASSWORD || 'ca2pass',
  });

  await client.connect();
  const passwordHash = await bcrypt.hash('Password123', 10);
  await client.query(
    'UPDATE public.member SET password_hash = $1 WHERE email = ANY($2)',
    [passwordHash, ['testmember@example.com', 'testadmin@example.com']]
  );
  await client.end();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
