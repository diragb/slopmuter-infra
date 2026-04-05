# SlopMuter Infrastructure

Shared local development infrastructure for SlopMuter microservices: PostgreSQL, Redis, and LocalStack (SQS + SES).

## Prerequisites

- Docker and Docker Compose installed and running

## Setup

1. Copy the environment template:
  ```bash
   cp .env.example .env
  ```
2. Start Postgres, Redis, and LocalStack:
  ```bash
   yarn containers:start
  ```
3. Apply the database schema (single migration file):
  ```bash
   yarn db:migrate
  ```
4. Create SQS queues and verify the SES sender identity in LocalStack:
  ```bash
   yarn localstack:init
  ```
   Run this again after `docker compose down -v` if LocalStack data was wiped.

## Database migrations

All schema lives in `migrations/001_init.sql` (users, preferences, mute/reporting tables, category seed data, indexes). The migrate runner executes every `*.sql` file in `migrations/` in sorted order; with a single file, a fresh database is fully initialized in one step.

## LocalStack

**Image pin:** Compose uses `localstack/localstack:3.7.2`. Newer `latest` images (2026.x) expect a [LocalStack Cloud](https://www.localstack.cloud/) account and `LOCALSTACK_AUTH_TOKEN`, which causes a restart loop without it. To use `latest` or another new build, set `LOCALSTACK_AUTH_TOKEN` in `.env` (and optionally remove the pin in `compose.yml`), or keep `LOCALSTACK_ACKNOWLEDGE_ACCOUNT_REQUIREMENT=1` only while LocalStack allows that transitional escape hatch.

After changing the LocalStack image, run `docker compose pull localstack` and recreate the container (`docker compose up -d localstack`). If the old volume was corrupted by crash loops, use `docker compose down -v` once (this removes **all** compose volumes including Postgres unless you only tear down LocalStack).

| Setting  | Value                                                |
| -------- | ---------------------------------------------------- |
| Edge URL | `http://127.0.0.1:4566` (or `http://localhost:4566`) |
| Region   | `us-east-1` (default)                                |
| Services | SQS, SES                                             |


**Queues created by `yarn localstack:init`:**

- `slopmuter-report-created`
- `slopmuter-account-muted`
- `slopmuter-subscription-changed`
- `slopmuter-appeal-resolved`

Point app `SQS_*_QUEUE_URL` values at LocalStack URLs (for example `http://127.0.0.1:4566/000000000000/slopmuter-account-muted`) and set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` to dummy values such as `test` when using the AWS SDK against LocalStack.

**Scripts**


| Command                 | Purpose                                                                  |
| ----------------------- | ------------------------------------------------------------------------ |
| `yarn localstack:start` | Start only the LocalStack container                                      |
| `yarn localstack:stop`  | Stop the LocalStack container                                            |
| `yarn localstack:init`  | Run `scripts/init-localstack.js` (AWS SDK, works on Windows/macOS/Linux) |


## Connection details


| Service    | Connection                                                |
| ---------- | --------------------------------------------------------- |
| PostgreSQL | `postgresql://postgres:postgres@localhost:5433/slopmuter` |
| Redis      | `redis://localhost:6379`                                  |
| LocalStack | `http://127.0.0.1:4566`                                   |


PostgreSQL is exposed on port **5433** (host) to avoid conflicts with local Postgres installations.

## Microservices

This infrastructure is used by:

- [slopmuter-auth-ms](https://github.com/diragb/slopmuter-auth-ms) — Authentication service
- [slopmuter-users-ms](https://github.com/diragb/slopmuter-users-ms) — Users service
- [slopmuter-mute-ms](https://github.com/diragb/slopmuter-mute-ms) — Mute / reporting service
- slopmuter-payments-ms — Payments service (TBD)

Start Postgres, Redis, and LocalStack before running services that need them.

## Contributing

Contributions are welcome. Please open a Pull Request.

1. Fork the repository
2. Create your feature or fix branch (`git checkout -b feat/amazing-feature` or `git checkout -b fix/required-fix`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'` or `git commit -m 'fix: add required fix'`)
4. Push to the branch (`git push origin feat/amazing-feature` or `git push origin fix/required-fix`)
5. Open a Pull Request

## License

This project is licensed under the MIT License, see the [LICENSE](LICENSE) file for details.

## Links

- [Issues](https://github.com/diragb/slopmuter-infra/issues)
- [Repository](https://github.com/diragb/slopmuter-infra)
- [Author](https://github.com/diragb)

---

Made with ❤️ by [Dirag Biswas](https://github.com/diragb)