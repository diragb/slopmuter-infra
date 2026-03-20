# SlopMuter Infrastructure

Shared local development infrastructure for all SlopMuter microservices. Provides PostgreSQL and Redis that all services connect to.

## Prerequisites

- Docker and Docker Compose installed and running

## Setup

1. Copy the environment template:

   ```bash
   cp .env.example .env
   ```

2. Start the infrastructure:

   ```bash
   yarn containers:start
   ```

3. Run migrations (when available):

   ```bash
   yarn db:migrations
   ```

## Connection Details

Services should use these connection strings when running locally:

| Service | Connection |
|---------|------------|
| PostgreSQL | `postgresql://postgres:postgres@localhost:5433/slopmuter` |
| Redis | `redis://localhost:6379` |

PostgreSQL is exposed on port **5433** (host) to avoid conflicts with local Postgres installations.

## Microservices

This infrastructure is used by:

- [slopmuter-auth-ms](https://github.com/diragb/slopmuter-auth-ms) - Authentication service
- slopmuter-users-ms - Users service (TBD)
- slopmuter-mute-ms - Mute service (TBD)
- slopmuter-payments-ms - Payments service (TBD)

**Important:** You must have this infrastructure running before starting any microservice locally.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature or fix branch (`git checkout -b feat/amazing-feature` or `git checkout -b fix/required-fix`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'` or `git commit -m 'fix: add required fix'`)
4. Push to the branch (`git push origin feat/amazing-feature` or `git push origin fix/required-fix`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Links

- [Issues](https://github.com/diragb/slopmuter-infra/issues)
- [Repository](https://github.com/diragb/slopmuter-infra)
- [Author](https://github.com/diragb)

---

Made with ❤️ by [Dirag Biswas](https://github.com/diragb)
