const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
require('dotenv').config();

function getConnectionString() {
  if (process.env.DATABASE_URL && /^(postgres|postgresql):\/\//i.test(process.env.DATABASE_URL)) {
    return process.env.DATABASE_URL;
  }

  const user = encodeURIComponent(process.env.DB_USER || 'postgres');
  const password = encodeURIComponent(process.env.DB_PASSWORD || '');
  const host = process.env.DB_HOST || 'localhost';
  const port = process.env.DB_PORT || '5432';
  const database = process.env.DB_NAME || 'restaurant_db';

  return `postgresql://${user}:${password}@${host}:${port}/${database}?schema=public`;
}

const adapter = new PrismaPg({ connectionString: getConnectionString() });
const prisma = new PrismaClient({ adapter });

module.exports = prisma;
module.exports.getConnectionString = getConnectionString;
