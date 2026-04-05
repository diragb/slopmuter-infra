#!/usr/bin/env node
/**
 * Cross-platform LocalStack bootstrap.
 * Uses the AWS SDK v3 against the LocalStack endpoint so Windows/macOS/Linux behave the same.
 *
 * Prerequisites: `docker compose up -d localstack` (or `yarn localstack:start`).
 *
 * Env:
 *   LOCALSTACK_ENDPOINT — default http://127.0.0.1:4566
 *   AWS_DEFAULT_REGION  — default us-east-1
 *   SES_VERIFY_EMAIL    — default noreply@slopmuter.com
 */

// Packages:
const { SQSClient, CreateQueueCommand } = require('@aws-sdk/client-sqs')
const { SESClient, VerifyEmailIdentityCommand } = require('@aws-sdk/client-ses')
require('dotenv').config()

// Constants:
const endpoint = process.env.LOCALSTACK_ENDPOINT || 'http://127.0.0.1:4566'
const region = process.env.AWS_DEFAULT_REGION || 'us-east-1'
const sesVerifyEmail = process.env.SES_VERIFY_EMAIL || 'noreply@slopmuter.com'

const localCredentials = {
  accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test',
}

const clientConfig = {
  region,
  endpoint,
  credentials: localCredentials,
}

const QUEUE_NAMES = [
  'slopmuter-report-created',
  'slopmuter-account-muted',
  'slopmuter-subscription-changed',
  'slopmuter-appeal-resolved',
]

// Functions:
async function ensureQueue(sqs, name) {
  try {
    await sqs.send(new CreateQueueCommand({ QueueName: name }))
    console.log(`SQS queue created: ${name}`)
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    if (
      msg.includes('QueueAlreadyExists') ||
      msg.includes('already exists') ||
      err?.name === 'QueueAlreadyExists'
    ) {
      console.log(`SQS queue already exists: ${name}`)
      return
    }
    throw err
  }
}

async function main() {
  console.log(`LocalStack endpoint: ${endpoint} (region ${region})`)

  const sqs = new SQSClient(clientConfig)
  for (const name of QUEUE_NAMES) {
    await ensureQueue(sqs, name)
  }

  const ses = new SESClient(clientConfig)
  await ses.send(new VerifyEmailIdentityCommand({ EmailAddress: sesVerifyEmail }))
  console.log(`SES VerifyEmailIdentity: ${sesVerifyEmail}`)

  console.log('LocalStack init finished.')
}

// Execution:
main().catch(err => {
  console.error(err)
  process.exit(1)
})
