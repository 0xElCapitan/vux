-- VUX v1 off-chain replica — PostgreSQL 16.4
--
-- REFERENCE SHAPE, NOT THE RUNNING SCHEMA. Nothing in this repository executes
-- this file. ponder owns the live DDL and builds it from `ponder.schema.ts`;
-- this is here so an independent party can rebuild the replica in their own
-- warehouse and know what the columns and invariants mean.
--
-- Audit M-2 found this file's constraints described in source comments as
-- active defences while nothing applied them. Where the running system enforces
-- an invariant, it now does so in a path that actually executes:
--   * UNIQUE (tx_hash, log_index)  -> `uniqueIndex()` in ponder.schema.ts
--   * legs_sum, cause domain,
--     class-is-never-backing,
--     direction domain             -> `src/schema-constraints.ts`, applied at
--                                     `setup` and PROVEN to reject a violating
--                                     row before any event is indexed
--   * ref_epoch_id FOREIGN KEY     -> deliberately NOT applied; it would couple
--                                     row-deletion order during a reorg
--                                     rollback. Declared below for consumers
--                                     who want it; see schema-constraints.ts.
--
-- The accepted schema, sdd.md §3.3, reproduced exactly. This store is DERIVED,
-- disposable, and rebuildable from genesis by re-indexing chain events; it never
-- feeds anything back on-chain (sdd.md:L474). On-chain events remain canonical
-- (sdd.md:L930).
--
-- Naming note that is load-bearing rather than cosmetic: the disclosed Strategic
-- NAV column is `strategic_nav_disclosed` and the word "backing" never labels a
-- Strategic value (FR-14.4). Hard backing `B` is the Reserve's physical WETH
-- balance and nothing else (INV-10).

BEGIN;

CREATE TABLE IF NOT EXISTS settlement (
    epoch_id        BIGINT PRIMARY KEY,
    block_number    BIGINT NOT NULL,
    tx_hash         BYTEA  NOT NULL,
    ts              TIMESTAMPTZ NOT NULL,
    outgoing_king   BYTEA  NOT NULL,
    new_king        BYTEA  NOT NULL,
    bootstrap       BOOLEAN NOT NULL,
    price           NUMERIC(78,0) NOT NULL,
    king_leg        NUMERIC(78,0) NOT NULL,
    strategic_leg   NUMERIC(78,0) NOT NULL,
    reserve_leg     NUMERIC(78,0) NOT NULL,
    b_pre           NUMERIC(78,0) NOT NULL,
    s_pre           NUMERIC(78,0) NOT NULL,
    d_r             NUMERIC(78,0) NOT NULL,
    q_raw           NUMERIC(78,0) NOT NULL,
    q_safe          NUMERIC(78,0) NOT NULL,
    q_mint          NUMERIC(78,0) NOT NULL,
    next_opening    NUMERIC(78,0) NOT NULL,
    epoch_ups       NUMERIC(78,0) NOT NULL,
    -- Adaptive legs (2026-08-12): strategic_leg = residual <= floor(12%*price);
    -- reserve_leg = hardTarget >= nominal 8%+dust; d_need = ceil(q_raw*b_pre/s_pre)
    -- is derivable from the emitted fields. The sum law is unchanged.
    CONSTRAINT legs_sum CHECK (king_leg + strategic_leg + reserve_leg = price)
);

CREATE TABLE IF NOT EXISTS supply_change (
    id           BIGSERIAL PRIMARY KEY,
    block_number BIGINT NOT NULL,
    tx_hash      BYTEA NOT NULL,
    -- The log's position within its transaction. Added so the one-row-per-log
    -- invariant is enforced by the database and not only by the ingesting code:
    -- `VUX.burn` is permissionless, so two identical burns in one transaction are
    -- reachable, and any identity derived from (tx, direction, amount) would
    -- collapse them into one row and understate S. `(tx_hash, log_index)` is
    -- unique by construction. The surrogate BIGSERIAL key is retained so the
    -- accepted §3.3 shape is unchanged for consumers.
    log_index    INTEGER NOT NULL,
    cause        TEXT NOT NULL CHECK (cause IN
                 ('genesis','settlement_mint','redemption_burn','vyrf_burn','other_authorized_burn')),
    delta        NUMERIC(78,0) NOT NULL,   -- signed
    ref_epoch_id BIGINT REFERENCES settlement(epoch_id),
    UNIQUE (tx_hash, log_index)
);

CREATE TABLE IF NOT EXISTS redemption (
    id BIGSERIAL PRIMARY KEY, block_number BIGINT, tx_hash BYTEA, ts TIMESTAMPTZ,
    redeemer BYTEA, recipient BYTEA,
    q NUMERIC(78,0), payout NUMERIC(78,0), b_pre NUMERIC(78,0), s_pre NUMERIC(78,0)
);

CREATE TABLE IF NOT EXISTS strategic_flow (
    id BIGSERIAL PRIMARY KEY, block_number BIGINT, tx_hash BYTEA, ts TIMESTAMPTZ,
    direction TEXT CHECK (direction IN ('in','out')),
    class TEXT NOT NULL,          -- FR-9.1 classes; NEVER 'backing'
    asset BYTEA, amount NUMERIC(78,0), counterparty BYTEA
);

CREATE INDEX IF NOT EXISTS idx_settlement_block ON settlement(block_number);
CREATE INDEX IF NOT EXISTS idx_supply_cause     ON supply_change(cause);
CREATE INDEX IF NOT EXISTS idx_strategic_class  ON strategic_flow(class);

-- --------------------------------------------------------------------------
-- Guard: the class vocabulary may never include "backing" (FR-14.4).
-- Stated as a CHECK rather than a convention, because a convention is exactly
-- what erodes. Strategic value is contributed principal, returned principal,
-- fee yield, or other realized revenue — never Hard backing.
-- --------------------------------------------------------------------------
ALTER TABLE strategic_flow DROP CONSTRAINT IF EXISTS class_is_never_backing;
ALTER TABLE strategic_flow ADD CONSTRAINT class_is_never_backing
    CHECK (lower(class) NOT LIKE '%backing%');

-- --------------------------------------------------------------------------
-- Analytics view — exactly the prd.md:L534 report list.
--
-- `strategic_nav_disclosed` is DISCLOSED information, not derived protocol
-- truth: class 5 (UnrealizedMark) "is never an event at all, because a mark is
-- not a transfer" (INV-30), so NAV cannot be reconstructed from chain events and
-- is left NULL here until a disclosure source supplies it. NULL is the truthful
-- value for "not disclosed", and it is never silently coerced to zero, which
-- would read as a measured "no value".
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW accounting_truth AS
SELECT
    (SELECT COALESCE(SUM(delta), 0) FROM supply_change)                                    AS current_supply,
    (SELECT COALESCE(SUM(delta), 0) FROM supply_change WHERE cause = 'genesis')            AS genesis_pol_inventory,
    (SELECT COALESCE(SUM(q_raw), 0) FROM settlement)                                       AS cumulative_raw_opportunity,
    (SELECT COALESCE(SUM(q_mint), 0) FROM settlement)                                      AS completed_mints,
    (SELECT COALESCE(-SUM(delta), 0) FROM supply_change WHERE cause = 'redemption_burn')   AS redemption_burns,
    (SELECT COALESCE(-SUM(delta), 0) FROM supply_change WHERE cause = 'vyrf_burn')         AS vyrf_burns,
    (SELECT COALESCE(-SUM(delta), 0) FROM supply_change
        WHERE cause = 'other_authorized_burn')                                             AS other_authorized_burns,
    (SELECT COALESCE(SUM(amount), 0) FROM strategic_flow
        WHERE class = 'ContributedPrincipal')                                              AS strategic_contributed_principal,
    (SELECT COALESCE(SUM(amount), 0) FROM strategic_flow
        WHERE class IN ('PolFeeYield', 'OtherRealizedRevenue'))                            AS realized_revenue,
    NULL::NUMERIC(78,0)                                                                    AS strategic_nav_disclosed;

COMMENT ON COLUMN accounting_truth.strategic_nav_disclosed IS
    'DISCLOSED Strategic NAV. Never "backing" (FR-14.4). Not event-derivable: marks are not transfers (INV-30). NULL means not disclosed — never coerce to 0.';

COMMIT;
