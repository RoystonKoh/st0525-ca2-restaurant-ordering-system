import "dotenv/config";
import { defineConfig } from "prisma/config";

function buildDatabaseUrl() {
  const configuredUrl = process.env.DATABASE_URL;
  if (configuredUrl && /^(postgres|postgresql):\/\//i.test(configuredUrl)) {
    return configuredUrl;
  }

  const user = encodeURIComponent(process.env.DB_USER || "postgres");
  const password = encodeURIComponent(process.env.DB_PASSWORD || "");
  const host = process.env.DB_HOST || "localhost";
  const port = process.env.DB_PORT || "5432";
  const database = process.env.DB_NAME || "restaurant_db";

  return `postgresql://${user}:${password}@${host}:${port}/${database}?schema=public`;
}

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    url: buildDatabaseUrl(),
  },
});
