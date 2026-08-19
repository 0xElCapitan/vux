# Q-6 evidence — canonical RH WETH native-wrap, verified on a real Robinhood Chain fork

**Sprint:** 7 (global 7) · **Task:** 7.1 · **Node:** `/implement sprint-7`
**Branch:** `sprint-7` · **Baseline:** `c58d41b8c77f3191114a5242c4bac9ff753f32dc`
**Status:** `Q6_PASS` — **operator-accepted** (`OPERATOR_ACCEPTANCE — SPRINT_7_Q6_NATIVE_WRAP_ACCEPTED`); the fallback pre-approval topology was NOT activated
**Verdict artifact:** `test/fork/RhWethFork.t.sol` (10/10 PASS on fork)
**Verbatim run:** [`q6-fork-run.txt`](q6-fork-run.txt)

> **Re-established after Tasks 7.2–7.6.** `forge fmt` reformatted the Q-6 suite
> file and its harness (`test/harness/Vm.sol`) gained two additive cheatcode
> declarations (`envUint`, `broadcast`) used only by the rehearsal script. Rather
> than rely on the stale result, the whole suite was re-run on a fresh fork —
> **block 39130641**, hash
> `0x662b5a64a30484e22a08db30fb3ed5c0517c49ad1077c2965b3776edd98da304` — and
> returned **10/10 PASS, unchanged**. `q6-fork-run.txt` holds that re-run; the
> block identity in §2 below is from the original accepted capture and both are
> reproducible by the same command with their respective block pins.

> Scope note. This document discharges **Q-6 only** (plus, recorded separately in
> §5, the narrow Sprint-5 WETH transfer-behaviour carry). No `GenesisDeployer.sol`
> implementation has begun. Tasks 7.2–7.6 are not started.

---

## 1. What Q-6 asks, and what would have counted as a pass

The accepted architecture funds genesis **in-transaction**: tx2 creates
`GenesisDeployer` carrying `W_POL + B0` as native value, and the constructor wraps
it with `WETH.deposit{value: msg.value}()` (sdd.md:L155, L161). The alternative —
approving or transferring WETH to a predicted address before launch — was rejected
because it publishes a predicted address pre-launch (sdd.md:L409). Q-6 is the
assumption that makes the accepted path viable (sdd.md §22).

The sprint mandate is explicit that observing a `deposit()` selector is **not**
evidence. The bar taken here:

| Required | How it is discharged |
|---|---|
| the call succeeds with native value | real `deposit{value:}` against the live deployed token |
| recipient's WETH balance increases by **exactly** the wrapped amount | measured delta `== msg.value`, exact equality |
| no prior approval or pre-funding of a predicted address | asserted: pre-balance `0`, all four relevant allowances `0` |
| compatible with **constructor** invocation / the accepted tx topology | the wrap happens inside a constructor, and the result is **spent** in that same constructor |
| observed WETH identity corresponds to the accepted RH trust surface | §3 |

---

## 2. Fork identity (reproducible facts)

| Fact | Value |
|---|---|
| Chain | Robinhood Chain **mainnet** |
| `eth_chainId` | **4663** (confirmed live and against docs.robinhood.com/chain/connecting) |
| RPC used | `https://rpc.mainnet.chain.robinhood.com` (official public endpoint) |
| Fork block | **38962712** |
| Fork block hash | `0x1ea922b6d34e4fb76c883ef33fdcba160c8c6fbbbc85e44fba71c7b43abe5092` |
| Parent hash | `0xefdaf2e404ac04f9a5fbe01dc14fc165091710861c8b17d9adadbcee6aa6743f` |
| State root | `0xca044552778f2f73553f5ced72e5454043e379d18a627ee1e23bd98841ed26c6` |
| Block timestamp | `1786982332` = 2026-08-17T15:58:52Z |
| Toolchain | forge `1.5.0-v1.5.0` @ `1c57854462289b2e71ee7654cd6666217ed86ffd` (the accepted pin) |

Exact command (also recorded verbatim in `q6-fork-run.txt`):

```bash
VUX_RH_FORK_BLOCK=38962712 \
VUX_RH_FORK_PARENT_HASH=0xefdaf2e404ac04f9a5fbe01dc14fc165091710861c8b17d9adadbcee6aa6743f \
forge test --match-path test/fork/RhWethFork.t.sol \
  --fork-url https://rpc.mainnet.chain.robinhood.com \
  --fork-block-number 38962712 -vv
```

### 2.1 Reproducibility limit — measured, not assumed (**operator-relevant**)

The official public RPC is **not an archive node**. Measured by binary search
during this task: historical state is retained for approximately **6,150 blocks
(~10 minutes)**; at ~10.6 blocks/second the window closes fast. A first evidence
run was captured at block 38945000 and that block's state was already pruned
minutes later.

Consequences, handled rather than hidden:

- The exact-block binding is a **runner input** (`VUX_RH_FORK_BLOCK`,
  `VUX_RH_FORK_PARENT_HASH`), not a source constant — a source-pinned block would
  make the suite unreproducible within minutes of being written.
- Every other assertion is **block-independent**, anchored on runtime-code hashes
  (§3), so a reviewer forking at *their own* fresh block reproduces the full result
  on the public RPC by simply omitting the two variables.
- Reproducing at *this exact block* requires an archive provider. The official docs
  recommend Alchemy (`https://robinhood-mainnet.g.alchemy.com/v2/{API_KEY}`), which
  needs an operator-supplied API key. **No credential was created, requested, or
  entered by this node.**

Both behaviours are proven, not asserted:

| Runner input | Identity case | Recorded outcome |
|---|---|---|
| correct block + parent hash | `test_ForkIdentity…` | **PASS** |
| block + 1 | `test_ForkIdentity…` | **FAIL** — `fork block number: got 38962712, expected 38962713` |
| wrong parent hash | `test_ForkIdentity…` | **FAIL** — `parent block hash: got 0xefdaf2e4…, expected 0x…01` |
| no pin at all (reviewer path) | `test_ForkIdentity…` | **PASS** |

---

## 3. Observed canonical-WETH identity vs. the accepted trust surface

Accepted authority: `docs/authority/vux-v1-canonical-specification-2026-08.md` §21
— canonical address `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73`, trust status
**YELLOW**, "the current implementation is byte-verified canonical Arbitrum
`aeWETH`", "the token, its WETH gateway, and its gateway router are upgradeable
infrastructure".

| Observation | Value | Corroborates |
|---|---|---|
| Address holds code | 2,202 bytes | accepted canonical address is live |
| `name()` / `symbol()` / `decimals()` | `"WETH"` / `"WETH"` / `18` | ordinary WETH surface |
| Proxy pattern | OZ `TransparentUpgradeableProxy` (identified from its own revert string) | §21 "upgradeable infrastructure" |
| EIP-1967 implementation | `0xC6B81b429797E0f555440b70cD99e032D7AE947e` (6,961 bytes) | — |
| EIP-1967 admin (`ProxyAdmin`) | `0xa3Acd31AFb851B4eB9DAD00F5204c01D924267dF` (1,681 bytes) | §21 external upgrade authority |
| `ProxyAdmin.owner()` | `0x2A153c6A1B66DBc930a8d7017230ab0253005C09` | the external authority that §21 says VUX cannot constrain |
| EIP-1967 beacon slot | `0x0` | not a beacon proxy |
| `l1Address()` | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` — **canonical Ethereum mainnet WETH9** | strongest on-chain corroboration of the aeWETH identity |
| `l2Gateway()` | `0x1D187C3E2dA52D72BC9C41e3AbA0fdFa6a7bF055` | aeWETH bridge surface |
| Implementation function set | `deposit()`, `depositTo(address)`, `withdraw(uint256)`, `withdrawTo(address,uint256)`, `bridgeMint`, `bridgeBurn`, `l1Address()`, `l2Gateway()`, `initialize(string,string,uint8,address,address)`, ERC20 + `permit` — and **no** `owner()`, **no** `pause()` | exactly the aeWETH surface; §21's "no ordinary pause … token-level owner mint" |
| Native backing | `address(WETH).balance == totalSupply()` exactly = `28389962371402383302911` wei | fully-backed 1:1 wrapper |

### 3.1 Byte-identity anchors (what makes this result transferable)

Cross-checked by two independent paths — local keccak-256 over the `eth_getCode`
bytes, and the node's own `codehash` — which **agree exactly**:

| Contract | Runtime codehash |
|---|---|
| Proxy `0x0Bd7…AD73` | `0x5706be52f64875fee65a2cec0d80e47a23d8793cbe85d214b48445e2d05f5353` |
| Implementation `0xC6B8…947e` | `0xbe1295f37be34ffe03ad779bda0ef278907e1856b51a3be2f35ee541d75d4650` |
| `ProxyAdmin` `0xa3Ac…67dF` | `0xa4b2186ab82fa36fb4ae158582e5615ea519e757c26c13ba4a33daaaed8902a7` |

These three are asserted in the suite. An upgrade of the token or its admin —
precisely the YELLOW principal risk — therefore turns into a **red test** rather
than a silent assumption drift.

---

## 4. Q-6 result — native wrap in constructor context

`ConstructorWrapProbe` (in `test/fork/RhWethFork.t.sol`) performs, **inside its own
constructor**, exactly the accepted genesis funding shape, and reverts on any
deviation — so a successfully deployed probe *is* the proof:

1. snapshot `balanceOf(self)`, `totalSupply()`, and the token's native balance;
2. `WETH.deposit{value: msg.value}()` — the only funding input is the transaction's
   native value;
3. require balance delta `== msg.value` **exactly**;
4. require supply delta `== msg.value` **exactly** (distinguishes genuine
   mint-on-deposit wrapping from a transfer out of some pre-funded pool);
5. require the token's native-ETH delta `== msg.value` **exactly**;
6. **spend it in the same constructor** — two transfers standing in for the POL leg
   and the exact-`B0` leg;
7. require residual `== 0` exactly.

Rehearsal amounts (not production conversion values — R-14 / operator-reserved):
`msg.value = 4.75 ether = 4750000000000000000` wei, POL leg `3.5 ether`, `B0` leg
`1.25 ether`.

**Measured result — every quantity exact, zero tolerance:**

| Quantity | Measured |
|---|---|
| probe pre-existing WETH balance | `0` |
| WETH credited to the probe | `4750000000000000000` = `msg.value` exactly |
| `totalSupply` delta | `4750000000000000000` = `msg.value` exactly |
| token native-ETH delta | `4750000000000000000` = `msg.value` exactly |
| POL leg delivered | `3500000000000000000` exactly |
| `B0` leg delivered | `1250000000000000000` exactly |
| probe residual after both legs | `0` exactly |
| allowances used anywhere | `0` (all four checked directions) |

Both halves of the required conclusion hold: the wrap **succeeds with native value
in constructor context**, and the wrapped WETH is **immediately spendable in that
same constructor** — which is what genesis steps 0 → 7 actually need.

### 4.1 Discrimination — the gate is not vacuous

Two in-suite controls plus four bounded source mutations. Mutations were applied,
run, reverted, and the file re-hashed **byte-identical**
(`d1b3fccebd5cd98c7801fbcf70d9aec3b31d9a0c88cf1d89c68b4e3300bfcdcb` before and
after).

| # | Perturbation | Expected | Observed |
|---|---|---|---|
| C1 | mock WETH: payable `deposit()` that credits nothing | probe rejects | **PASS** (`WrapDeltaMismatch`) |
| C2 | mock WETH: **non-payable** `deposit()` — the shape Q-6 would find if RH WETH were not the wrapped native asset | probe cannot construct | **PASS** (construction reverts) |
| M1 | pinned fork block `38945000 → 38945001` | identity fails | **FAIL** as required |
| M2 | pinned implementation address, last nibble flipped | identity fails | **FAIL** as required |
| M3 | balance-delta check weakened `!=` → `>` | control still caught | caught one layer later, by the **supply**-delta check (`SupplyDeltaMismatch`) — the checks are redundant by design |
| **M4** | **all three delta checks disabled at once** | control no longer caught | **the non-crediting mock is accepted** (`next call did not revert as expected`) **while the real fork path still PASSES** |

M4 is the load-bearing result: it isolates the delta assertions as the *only* thing
separating real native-wrap semantics from a token that merely accepts value, and
shows the live RH WETH satisfies them **on their merits**, not because the checks
are unfalsifiable.

---

## 5. Sprint-5 audit carry — current WETH transfer behaviour (recorded separately)

Narrow question, deliberately kept apart from Q-6: does the **currently deployed**
canonical WETH transfer path invoke recipient-controlled external callback logic?
This re-establishes on live code the YELLOW fact quoted at sdd.md:L227 ("no …
transfer-hook"), on which `Rig.take`'s measured-delta ordering leans (step 8a
`transfer` → step 8b `D_R` measurement) alongside its `nonReentrant` guard.

**Result: no recipient-controlled callback is invoked, on either side of the transfer.**

| Case | Method | Result |
|---|---|---|
| `transfer` to a recipient that reverts on **every** inbound call (payable `fallback`, no `receive`) | if the token called the recipient, the transfer would revert | transfer **succeeded**; recipient credited exactly `1 ether` |
| `transfer` to a recording recipient | exact call count, not absence-of-revert | `calls == 0`; credited exactly |
| `transferFrom(holder → hostile)` — the `Rig.take` payment-pull shape, where `from` is attacker-chosen | count on the **sender** side too | `calls == 0` on the sender; recipient credited exactly |
| complete log set of one transfer | `vm.recordLogs` enumeration | **exactly one** log; emitter is the token; topic0 is ERC-20 `Transfer` — no hook, notification, or auxiliary event |
| **control** | a mock WETH whose `transfer` *does* call the recipient and propagates its revert | recording receiver observes `calls == 1`; rejecting receiver makes the transfer revert |

The control is what makes the four `calls == 0` findings falsifiable. Note this is a
**live-execution** result: a static opcode walk over the implementation bytecode was
also run but is **not** relied upon (a linear disassembly cannot distinguish code
from trailing metadata, and it reported opcodes aeWETH does not have).

**No contradiction with the accepted YELLOW trust surface was found.** Every §21
property checkable from the token itself held: no pause, no token-level `owner()`,
no transfer fee (deltas exact), no rebase (supply moved only by the wrap amount), no
transfer hook. The `bridgeMint`/`bridgeBurn` gateway primitives and the upgradeable
proxy authority are present exactly as §21 already discloses — so the existing
reachability assessment of the Sprint-5 finding is **unchanged**, and no Sprint-5
code was touched or redesigned.

---

## 6. State of the tree at this gate

| Check | Result |
|---|---|
| `GenesisDeployer.sol` implementation begun? | **No** — no file exists; Tasks 7.2–7.6 not started |
| New external dependency or vendored source? | **None.** `vendor/` untouched; no `lib/`, no package added; census unchanged |
| New upstream source anywhere? | **None** — the WETH interface used is a VUX-authored declaration of the external runtime interface (never vendored, prd.md:L725) |
| Accumulated Forge suite | **397 passed / 0 failed**, + 10 skipped (this fork suite, off-fork) |
| Provenance gates `tools/provenance/run-all.sh` | **exit 0** — all gates green |
| SPDX gate saw the new file | yes — 68 VUX-owned Solidity files (was 67), `test/fork/RhWethFork.t.sol` enumerated |
| Files added | `test/fork/RhWethFork.t.sol` |
| Files modified | `test/harness/Vm.sol` (three cheatcode declarations: `skip`, `envOr×2`) |
| Commit / push / land | **none** |

### 6.1 Off-fork behaviour is a skip, never a silent pass

Run without `--fork-url`, all ten cases report `[SKIP]`. This is deliberate: a green
default run must not be readable as "Q-6 proven". The only Q-6 verdict is the
recorded fork run in `q6-fork-run.txt`.

---

## 7. Residuals and qualifications for operator disposition

1. **Public RPC is non-archive (~10-minute state window).** §2.1. Handled by
   env-var block pinning + byte-hash identity anchors. Reproducing *this exact
   block* needs an archive provider and therefore an operator-supplied API key.
   **Recommend:** the Sprint-8 runbook records an archive RPC as an operator input
   for launch-time re-verification of R-14 facts.
2. **`l1Address()` corroborates aeWETH; it is not a byte-for-byte re-verification
   of §21's "byte-verified canonical Arbitrum `aeWETH`" claim.** Full byte
   verification would require fetching the upstream aeWETH source/bytecode, which
   is a provenance-census action and is **not authorized** here (default deny). The
   evidence recorded instead is stronger where it counts for Q-6 — live behaviour
   plus the exact implementation codehash.
3. **The recorded implementation/admin/owner addresses are observations at one
   block.** They are now asserted, so a future upgrade fails the suite loudly.
   That is the intended tripwire, not a defect.
4. **Q-6 conclusion:** the accepted in-transaction native-wrap funding path is
   **viable as specified**. The fallback transition (pre-approval funding +
   §1.7 private-submission control) is **not** required and was **not**
   implemented.
