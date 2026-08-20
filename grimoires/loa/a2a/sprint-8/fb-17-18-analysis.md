# FB-17 / FB-18 — Documented Disclosure and Design Analysis

**Node:** `/implement sprint-8`, Task 8.7
**Register method:** these two rows are assigned to *documented disclosure and design analysis*, not to automated tests — `prd.md:L669` ("FB-17…FB-18 by documented disclosure and design analysis"), restated at `sdd.md:L869`. This file is that documentation. It is the evidence the traceability matrix names for both rows.

Two rows are analysed here rather than tested because in both the failure originates **outside every boundary VUX controls**. A test can only assert what VUX does when the external event happens; it cannot assert the event's absence, and pretending otherwise would be the dishonesty NFR-TRUST exists to forbid.

---

## FB-17 — Robinhood Chain unavailable

> **Accepted behaviour (prd.md:L666):** "Actions, including redemption, are delayed with the chain; balances are not reclassified."

### What the requirement actually forbids

The requirement is not "keep working during an outage" — nothing on-chain can. It is a prohibition on a specific, tempting repair: **reclassifying balances because they became temporarily unreachable.** A design that marked an unreachable holder's claim as impaired, or moved backing between accounting cells to "reflect" an outage, would convert a liveness failure into a solvency event. FB-17 forbids that.

### Why VUX satisfies it structurally

| Property | Where it comes from | Consequence during an outage |
|---|---|---|
| Backing is the Reserve's **physical WETH balance**, not a stored number | `src/HardReserve.sol` — `backing()` reads the token balance; INV-10 | There is no cell to reclassify. An outage cannot change a balance nobody can write to. |
| Redemption is **synchronous and atomic** | `HardReserve.redeem` burns then transfers in one call | The call either happens or does not happen. There is no partially-applied state to reconcile when the chain returns. |
| No time-based impairment, expiry, or forfeiture exists on the holder claim | `src/HardReserve.sol` — the redemption path takes no deadline and has no staleness branch | Elapsed downtime has no effect on what a holder is owed. |
| No oracle, keeper, or heartbeat can mark state stale | there is none in the P0 surface | Nothing exists that could observe the outage and act on it. |

The honest statement is therefore stronger than "we handle outages": **VUX has no mechanism capable of reclassifying a balance in response to time or liveness.** Absence of the mechanism is the guarantee.

### Where the surface tells the truth about it

`sdd.md:L838` binds the off-chain behaviour: "Frontend: RPC failure degrades to explicit 'data unavailable' states — never stale numbers presented as live… Chain outage messaging follows FB-17: actions are delayed, balances are not reclassified."

Implemented at `web/components/Unavailable.jsx`, with the copy assertions in `web/tests/truth-copy.spec.js` and `web/tests/chain-guard.spec.js`. The frontend is where FB-17 could most plausibly be violated — by showing a cached number as if it were live — and that is the part which *is* mechanically tested. The on-chain half needs no test because it has no code to test.

### Residual

Actions are genuinely unavailable while the chain is. Redemption is delayed exactly as long as the outage lasts. VUX does not claim otherwise, offers no alternative settlement path, and holds no off-chain escape hatch. **This is a liveness limitation, disclosed, not mitigated.**

---

## FB-18 — Canonical RH WETH adversely upgraded

> **Accepted behaviour (prd.md:L667):** "Transferability or principal may fail under the disclosed external trust risk; VUX cannot repair it with Reserve discretion."

### The dependency, stated exactly

Hard backing is canonical Robinhood Chain WETH at `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73`. Accepted status **YELLOW** (prd.md:L721):

- the current implementation is byte-verified canonical Arbitrum `aeWETH`;
- current behaviour has no ordinary pause / blacklist / fee / rebase / arbitrary-mint / force-transfer / transfer-hook;
- bridge infrastructure includes a gateway-only burn primitive constrained by the deployed gateway;
- **the token, gateway, and router are upgradeable**;
- **a 7-of-8 Robinhood Chain authority holds a direct no-delay upgrade path** (alongside a parallel seven-day timelock path);
- a future upgrade could block, burn, freeze, or seize Reserve WETH;
- **VUX cannot constrain that authority or guarantee an exit window.**

### Why this cannot be engineered away

Every candidate mitigation was considered and each fails for a structural reason, not a difficulty reason:

| Candidate | Why it fails |
|---|---|
| Wrap or re-issue the backing asset | The claim would then be on a VUX-issued wrapper, which reintroduces exactly the discretionary authority the Hard Reserve exists to eliminate. |
| Hold a second backing asset | Multi-asset backing makes redemption a discretionary allocation decision. INV-10 (backing *is* the physical WETH balance) would no longer hold. |
| Add a pause / migration authority to the Reserve | Directly contradicts the ownerless, immutable Reserve — the property the whole exit right rests on. A migration key is a seizure key. |
| Oracle-monitor the WETH implementation and react | Reacting requires an authority to react *with*. There is none, by design. |
| Timelock or delay redemption to "outrun" an upgrade | The adverse path is explicitly **no-delay**. There is nothing to outrun. |

Each mitigation removes the property it is meant to protect. That is why the accepted architecture records this as **the one honest residual** (`sdd.md:L962`, threat row 22) and why `sdd.md:L372` says "not a VUX-authority question; honesty is the mitigation".

### What VUX does do

Failing closed is not a repair, but it is not nothing:

1. **`SafeERC20` at every token boundary** — a WETH that starts returning `false` or reverting causes the surrounding VUX operation to revert rather than proceed on a false premise.
2. **The step-8b `D_R == routed amount` equality** (`src/Rig.sol`, `InconsistentReserveDelta`) — settlement measures the Reserve's *actual* balance delta and reverts unless it equals what was routed. A WETH that becomes deflationary, fee-on-transfer, or partially-crediting halts settlement instead of silently under-backing the token. `sdd.md:L942` records this as "halt over corruption".
3. **Redemption failure is atomic** — if the transfer fails, the burn does not stand. A holder never loses VUX to a failed payout.

So the observable behaviour under an adverse upgrade is **halt**, not **quiet corruption**. That distinction is the entire value of the fail-closed design, and it is exercised by the abnormal-token tests already carried in the suite (`test/reserve/HardReserveRedemption.t.sol`, `test/rig/RigSettlement.t.sol`, `test/rig/RigFailureBehaviors.t.sol`).

### The disclosure obligation this creates

Because the risk cannot be removed, the accepted design makes **saying so** mandatory and verbatim (INV-36, §13). The exact accepted sentence, reproduced character-for-character from `prd.md:L722-L723` and carried as a single constant at `web/lib/truth-copy.js:105-106`:

> The VUX Hard Reserve contract is designed to be immutable and ownerless. Its backing asset is canonical Robinhood Chain WETH, which retains an external Robinhood Chain governance and upgrade trust assumption.

`<ReserveDescription/>` (`web/components/ReserveDescription.jsx`) is the **only** component permitted to describe the Reserve as ownerless or immutable, and it always renders both sentences together. The coupling is structural rather than editorial: there is no code path that emits the first claim without the second. `web/tests/truth-copy.spec.js` asserts the verbatim text and the absence of prohibited trustless phrasing.

### Residual

**Catastrophic, external, unmitigable, disclosed.** A 7-of-8 Robinhood Chain authority can, on a no-delay path, block or seize the WETH backing the Hard Reserve. VUX cannot prevent it, cannot detect it in advance, and cannot compensate holders afterwards. Nothing in VUX may describe the system as trustless while this holds — see `grimoires/loa/a2a/sprint-8/trust-inventory.md` for the full YELLOW inventory and the no-trustless-claims review.

---

## Cross-references

| Artifact | Role |
|---|---|
| `grimoires/loa/a2a/sprint-8/trust-inventory.md` | YELLOW inventory, trust boundaries, no-trustless-claims review (NFR-TRUST) |
| `grimoires/loa/a2a/sprint-8/traceability-matrix.md` | names this file as the FB-17 / FB-18 evidence |
| `web/lib/truth-copy.js` | the verbatim YELLOW constant (single source) |
| `web/components/ReserveDescription.jsx` | the structural coupling (INV-36) |
| `web/tests/truth-copy.spec.js` | mechanical assertion of the verbatim text |
| `prd.md` §13, L666-L667, L721-L723 | accepted authority for both rows |
| `sdd.md:L372`, `L801`, `L838`, `L942`, `L962` | accepted design analysis this file restates and grounds |
