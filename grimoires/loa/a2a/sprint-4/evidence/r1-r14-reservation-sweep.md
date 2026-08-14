# R-1…R-14 reservation sweep — nothing operator-reserved was frozen

**Node:** Sprint 4 implementation (Task 4.9)
**Carries:** prd.md §16 (L776-L795), §17 quarantine (prd.md:L818), INV-31, sprint.md Sprint 4 AC-5
**Method:** every row of the Operator-Reserved Decision Register walked against the Sprint-4
implementation subject; each row records what the code *does* contain and why that is not a
resolution of the reserved decision.

---

## Result

**No R-1…R-14 decision is resolved, defaulted, or frozen by Sprint-4 code.** Every value that
had to exist for a test to run is a fixture value in `test/`, and no fixture value is reachable
from `src/`.

## Mechanical checks

```bash
bash tools/provenance/verify-quarantine.sh          # §17 guidance values absent from src/test/script/tools/.github/foundry.toml
jq -r '.methodIdentifiers | keys[]' out/StrategicTreasury.sol/StrategicTreasury.json
```

`test/treasury/TreasurySurface.t.sol::test_NoStoredPolicyRatioConstantIsExposed` enumerates the
ratio-shaped getters that must not exist; `test_TheExternalSurfaceIsExactlyTheAcceptedOne` makes
the surface **closed-world**, so a policy constant cannot be added later without failing a test.

---

## Row-by-row

| row | reserved decision | what Sprint 4 contains | why it is not a resolution |
|---|---|---|---|
| **R-1** | Strategic portfolio weights | `admitStrategy(strategy, asset, cap, mode)` — an empty registry at launch | No strategy, weight, or asset is admitted in code. The registry is machinery; the portfolio is operator input. |
| **R-2** | POL size and portfolio share | *nothing* — the POL sleeve is Sprint 5 | No POL cell, function, or sizing constant exists in this subject. |
| **R-3** | Strategic deployment timing | `deployToStrategy` / `deployMarginalBySignal` are operator-triggered; `ADMISSION_DELAY` gates *admission maturity*, never deployment cadence | Receiving the settlement leg forces nothing: bare inventory sits until an operator acts. No schedule, timer, or auto-deploy exists. |
| **R-4** | Strategic dry powder | Holding raw WETH is the treasury's default state — there is no cell for it and nothing consumes it | Indefinite holding is a first-class state precisely because no code path drains it. |
| **R-5** | Strategy admission | The admission/removal/recall authority surface, gated on `OPERATOR_ROLE` | Whom to admit, at what cap, with what diligence, is entirely operator input. `removeStrategy`/`recallFromStrategy` are unblockable, as required. |
| **R-6** | LSG activation timing | `activateLSG(address)` / `deactivateLSG()`, launch value `address(0)` | No calendar, no block height, no auto-activation. `TreasuryLsgBoundary.t.sol::test_TimeAloneNeverActivatesLsg` proves a year of block time changes nothing. |
| **R-7** | Internal LSG readiness thresholds | *nothing* — no threshold of any kind | F-50 preserved: no numeric readiness gate appears in code. `TreasurySurface.t.sol::test_NoLsgMechanismShipsAtP0` asserts `activationThreshold()` and the P1 mechanism surface are absent. |
| **R-8** | ROOT/GIGA exposure | *nothing* — no ROOT/GIGA symbol, admission, or look-through cap exists | Admission is generic and empty; no asset is named in `src/`. |
| **R-9** | General revenue policy **execution** | `allocateRevenue(asset, toCompound, toHard, toOps, toSignalers)` — four **call-time arguments** | Zero stored ratios. The founder-accepted `50/25/20/5/0` doctrine is future doctrine and is **not implemented by any P0 surface** (FR-12.4): no waterfall constant, no `*_BP` getter, no `setWaterfall`. Each call is the disclosed policy act, evented in full. |
| **R-10** | Operator Reserve administration & compensation execution | `toOps` = payment of an **actual approved operating expense** only; `setOpsRecipient` | No Operator Reserve contract, credit ledger, accumulator, sweep, runway target, reforecast, or allocator-exclusion exists. Nobody holds a claim before an approved expense is incurred: with zero realized revenue every leg reverts (`TreasuryRevenue.t.sol::test_WithZeroRevenueEveryLegReverts`). |
| **R-11** | Signaler rewards | `signalerBudget[asset]` earmark + `fundSignalerProgram(asset, amount, start, end)` | Amount, window, and whether to fund at all are call-time operator inputs. The earmark is revenue-bounded upstream; no reward rate, share, or eligibility rule exists in this subject. |
| **R-12** | Bribe experiment sizing | *nothing* — `fundBribe` is a P1 module function and is absent | `TreasurySurface.t.sol` asserts `fundBribe(...)` is not on the treasury surface. |
| **R-13** | Market-infrastructure tactics | *nothing* — and, per the 2026-08-12 remediation, no market-infrastructure **revenue leg** either | `toMarketInfra` and `marketInfraBudget` do not exist as arguments, getters, or selectors (`test_SignalerBudgetIsTheSoleEarmark`, `test_AllocateRevenueHasExactlyFourLegs`). Market infrastructure remains fundable through Strategic capital deployment policy. |
| **R-14** | Deployment facts | Constructor arguments: `weth`, `vux`, `hardReserve`, `poolDeployer`, `pool`, `feeTier` — all supplied at deployment, none defaulted | The fee tier is **asserted against the pool**, never chosen here; tick bounds are **derived** from the verified pool's `tickSpacing()`. `VuxPoolDeployer` domain-**checks** `(fee, tickSpacing)` (`fee < 1_000_000`, `0 < tickSpacing < 16384`) without freezing either value. |

---

## Fixture values used for testing, and why they are not policy

All live under `test/` and are unreachable from `src/`:

| value | file | note |
|---|---|---|
| `FIXTURE_FEE = 3_000`, `FIXTURE_TICK_SPACING = 60` | `test/treasury/TreasuryFixture.sol` | A pool cannot be created without *some* pair; R-14 fact, domain-checked never frozen. |
| `BOOTSTRAP_OPENING` / `MINIMUM_OPENING` / `DECAY_FLOOR` / `B0` | `test/treasury/TreasuryFixture.sol` | Carried over verbatim from the accepted Sprint-3 `RigFixture` rehearsal set. |
| `FIXTURE_SALT` | `test/treasury/TreasuryFixture.sol` | In production this is a launch secret until the launch block (sdd.md:L270); `verify-launch-hygiene.sh` passes on this subject. |
| caps, deployment sizes, reward amounts | all treasury test files | Arbitrary test magnitudes; none appears in `src/`. |

## §17 quarantine

`tools/provenance/verify-quarantine.sh` passes on the full subject (10/10 patterns clean),
covering the LSG readiness window, the capital and distributed-VUX gates, the dry-powder window,
operator-share/NAV-ceiling concepts, ROOT/GIGA look-through caps, signaler measurement guidance,
and general revenue split ratios.
