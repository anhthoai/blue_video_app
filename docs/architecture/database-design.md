# Database Design

The database schema is managed via **Prisma**.

## Source of truth

- Prisma schema: [`backend/prisma/schema.prisma`](../../backend/prisma/schema.prisma)

## Common commands

Run from `backend/`:

```bash
npx prisma generate
npx prisma db push
npx prisma migrate dev
npx prisma studio
```

More details:
- Backend README: [`backend/README.md`](../../backend/README.md)
- Migration commands guide: [`backend/MIGRATION_COMMANDS.md`](../../backend/MIGRATION_COMMANDS.md)

## Backups / references

- Reference dumps live in [`references/`](../../references/) (useful for restoring into PostgreSQL).
- Backup strategy doc: [`docs/operations/backup-strategy.md`](../operations/backup-strategy.md)
