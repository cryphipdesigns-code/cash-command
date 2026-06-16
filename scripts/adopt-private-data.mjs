#!/usr/bin/env node
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

const SUPABASE_URL = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const OWNER_USER_ID = process.env.CASH_OWNER_USER_ID || process.env.OWNER_USER_ID || "";

if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !OWNER_USER_ID) {
  console.error([
    "Missing required environment.",
    "Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and CASH_OWNER_USER_ID.",
  ].join("\n"));
  process.exit(1);
}

const headers = {
  apikey: SERVICE_ROLE_KEY,
  Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

async function request(endpoint, options = {}) {
  const response = await fetch(`${SUPABASE_URL}${endpoint}`, {
    ...options,
    headers: {
      ...headers,
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${options.method || "GET"} ${endpoint} failed: ${response.status} ${text}`);
  }
  return body;
}

function findDuplicateKeys(rows) {
  const counts = new Map();
  rows.forEach((row) => {
    counts.set(row.key, (counts.get(row.key) || 0) + 1);
  });
  return [...counts.entries()].filter(([, count]) => count > 1);
}

async function main() {
  const backupDir = path.join(process.cwd(), ".tmp-backups");
  await mkdir(backupDir, { recursive: true });

  const allRows = await request("/rest/v1/app_fields?select=*");
  const backupPath = path.join(backupDir, `cash-app-fields-${Date.now()}.json`);
  await writeFile(backupPath, JSON.stringify(allRows, null, 2));
  console.log(`Backed up ${allRows.length} app_fields rows to ${backupPath}`);

  const legacyRows = allRows.filter((row) => !row.user_id);
  if (!legacyRows.length) {
    console.log("No legacy rows with null user_id found.");
    return;
  }

  const duplicateLegacyKeys = findDuplicateKeys(legacyRows);
  if (duplicateLegacyKeys.length) {
    console.error("Refusing to adopt because duplicate legacy keys were found:");
    duplicateLegacyKeys.forEach(([key, count]) => console.error(`- ${key}: ${count}`));
    process.exit(1);
  }

  const ownedKeys = new Set(allRows.filter((row) => row.user_id === OWNER_USER_ID).map((row) => row.key));
  const collisions = legacyRows.filter((row) => ownedKeys.has(row.key)).map((row) => row.key);
  if (collisions.length) {
    console.error("Refusing to adopt because the owner already has rows for these keys:");
    collisions.forEach((key) => console.error(`- ${key}`));
    process.exit(1);
  }

  await request("/rest/v1/app_fields?user_id=is.null", {
    method: "PATCH",
    headers: {
      Prefer: "return=representation",
    },
    body: JSON.stringify({ user_id: OWNER_USER_ID }),
  });

  const remaining = await request("/rest/v1/app_fields?select=key&user_id=is.null");
  console.log(`Adopted ${legacyRows.length} legacy rows for ${OWNER_USER_ID}.`);
  console.log(`Remaining unowned rows: ${remaining.length}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
