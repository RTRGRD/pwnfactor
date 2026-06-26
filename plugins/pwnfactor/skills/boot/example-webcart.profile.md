# Orchestration profile — Webcart (worked example)

A worked instance of `orchestration-profile.template.md` — a **fictional e-commerce SaaS**, to show a
filled-in profile. Your project's specifics differ; the SHAPE is what ports. Copy the template to
`.claude/orchestration-profile.md` and fill it for your repo.

## Components & parallel seams
- **Components:** `apps/api` (Node/TS backend), `apps/web` (React/TS storefront), `packages/shared` (TS contracts shared by both).
- **Single-slot:** ALL of `apps/web` shares one pnpm/node_modules/build — one agent at a time, never two web agents or both running `pnpm`. api-vs-web is the real parallel seam.

## Shared-contract barrier
- **Location:** `packages/shared`.
- **Sync rule:** the API DTOs and the web client types are hand-mirrored (NOT codegen); update both barrels (`packages/shared/src/api.ts` ↔ the web client's `types.ts`), any shared enum (e.g. `OrderStatus`), and pass `packages/shared/tests/parity.test.ts`. One agent owns `packages/shared` per feature — two corrupt the barrels/enum even in separate worktrees.

## Migration ritual
- **Tool:** Prisma (Postgres).
- **Steps:** `prisma migrate dev --name <change>` (explicit, ordered), commit the generated SQL, pass `apps/api/tests/migration.test.ts` (asserts `migrate deploy` on a fresh DB == the schema).
- **After:** re-seed the demo DB before any consumer validates the live backend.

## Mutation & rollback model
- **Rails:** the destructive/irreversible action here is a **payment refund** — idempotency-key + checkpoint-before-apply + a separate reversal.
- **Semantics:** `refundOrder(orderId, idempotencyKey)` is operator/API-initiated; a refund records a `RefundLog` row; a failed refund marks the order `REFUND_FAILED` (NOT auto-reversed) and is not re-refundable until reconciled. The reversal is a separate call, verified by reading the payment processor's state back.
- **Proof of green (payment-mutating unit):** a test drives (a) a dry-run/preview = no charge; (b) the refund records a `RefundLog`; (c) re-invoking with the SAME idempotency-key is a no-op (not a double refund); (d) the audit trail is metadata-only (no card data). Asserting the rail merely "exists" is RED.
- A new payment method = a `PaymentProvider` adapter (rides the existing flow). A new capability (e.g. partial refunds) = a new state in the order state machine — bigger.

## Hotspot files (never split across parallel agents)
`apps/api/src/payments/service.ts`, `apps/api/src/orders/engine.ts`, the two `packages/shared` barrels, `apps/api/src/audit.ts`.

## Build / refresh steps
- **Refresh** after any `apps/api` / `packages/shared` / migration change (the demo backend does NOT hot-reload the schema): `docker compose -f infra/docker-compose.yml up -d --build api`. Keep secrets in `infra/.env` (gitignored).
- **Verify after:** the new endpoint responds + `prisma migrate status` is clean.
- **Dev run:** api `pnpm --filter api dev`; web `pnpm --filter web dev`.

## Test / lint / typecheck
- **Test:** `pnpm --filter api test` (vitest); `pnpm --filter web build`; `packages/shared/tests/parity.test.ts` (contract parity).
- **Lint:** `pnpm lint` (eslint).
- **Typecheck:** `pnpm -r exec tsc --noEmit`.

## Ground-truth oracle (what `/pwnfactor:validate` reads)
- **Oracle:** a **staging URL** — a real request against the deployed staging API returns the real response (cloud-reachable, so validation can run in CI). For a payment change: hit the staging refund endpoint with a test card and read the processor's sandbox state back. Read ITS verdict, not your classifier's.

## Project-specific risk signals (HIGH beyond the defaults)
the **payments / billing path**, auth / sessions, the webhook handlers (signature verification), any PII export.

## Security sweep (pre-prod gate)
- **Prod-push trigger:** deploying the api image to production, or cutting a release tag.
- **Scanners available:** `pnpm audit` (deps), grep-based secret scan, the `panel-security` agent for surface review.
