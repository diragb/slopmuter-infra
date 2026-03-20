// Packages:
const fs = require('fs')
const path = require('path')
const { Client } = require('pg')
require('dotenv').config()

// Functions:
async function run() {
  const databaseUrl = process.env.DATABASE_URL

  if (!databaseUrl) {
    throw new Error('DATABASE_URL is not set')
  }

  const client = new Client({
    connectionString: databaseUrl,
  })

  await client.connect()

  const migrationsDir = path.join(__dirname, '..', 'migrations')
  const files = fs
    .readdirSync(migrationsDir)
    .filter(file => file.endsWith('.sql'))
    .sort()

  for (const file of files) {
    const filePath = path.join(migrationsDir, file)
    const sql = fs.readFileSync(filePath, 'utf8')
    console.log(`running migration: ${file}`)
    await client.query(sql)
  }

  await client.end()
  console.log('all migrations completed')
}

// Execution:
run().catch(error => {
  console.error(error)
  process.exit(1)
})
