# PROV-5 clean-source statement — Sprint 4 subject

**Node:** Sprint 4 implementation (Task 4.9)
**Carries:** PROV-4, PROV-5 (prd.md:L761-L764), INV-37, DELTA §3/§4, refreeze §8
**Status:** implementation-side statement for `/review-sprint sprint-4`

The required similarity statement is kept in this file rather than in the Solidity headers,
because naming the prohibited projects in `src/` would trip the repository's own
prohibited-source detector (`tools/provenance/verify-census.sh`, which greps VUX-owned Solidity
for `liquid-signal-governance|gumball6900|give.fun|olympus`). The same convention was used for
`HardReserve.sol` in Sprint 2 (`src/HardReserve.sol:L34-L43`).

---

## Per-file provenance class

| file | class | statement |
|---|---|---|
| `src/StrategicTreasury.sol` | `VUX_ORIGINAL_CLEAN_SOURCE` | Written from prd.md FR-8/FR-9/FR-12/FR-13 and sdd.md:L135-L148, §1.10, §1.11 only. No treasury, vault, adapter, strategy-registry, reward-distributor, or signal-governance implementation was consulted as an implementation source. |
| `src/interfaces/ILSGModule.sol` | `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` (DELTA §3/§4) | Designed from the PRD boundary alone. The pinned external signal-governance repository remains **prohibited source** (PROV-4) and **was not consulted** — consistent with sdd.md:L324, which records the same for the §1.11 design. |
| `src/interfaces/IStrategyAdapter.sol` | `VUX_ORIGINAL_CLEAN_SOURCE` | Shape derived from the accepted §1.10 guards; no external vault/adapter interface was consulted. |
| `src/interfaces/IVUXBurnable.sol` | `VUX_ORIGINAL_CLEAN_SOURCE` | One member, the ERC-20-conventional `burn(uint256)` signature. Reproduces no text from the allowlisted Miner Manifold `IUnit.sol`. |
| `src/v3core/VuxPoolDeployer.sol` | **VUX-owned derivative** of pinned upstream v3-core | Derives from `vendor/uniswap-v3-core-v1.0.0/contracts/UniswapV3PoolDeployer.sol` (commit `e3589b192d0be27e100cd0daaf6c97204fdb1899`) **by inheritance, not by copying**. See below. |
| `test/**` (12 files) | `VUX_ORIGINAL_CLEAN_SOURCE` | VUX-original harness, fixtures, and mocks. No `forge-std`, no external test library, consistent with the accepted Sprint-1 minimal-harness decision. |

---

## `VuxPoolDeployer.sol` — the provenance-sensitive file

Task 4.1 is the only Sprint-4 file that touches upstream material, and the accepted
interpretation is explicit (sprint.md:L19): it is **VUX-owned derivative source compiled in the
pinned `=0.7.6` domain**, and it "must remain visibly distinct from the byte-identical
upstream-vendored v3-core census". Four facts establish that:

1. **It is not in the census.** It lives at `src/v3core/VuxPoolDeployer.sol` — inside the
   declared VUX source root `src` (`tools/provenance/census.sh` `VUX_SOURCE_ROOTS`), so every
   gate classifies it `vux`, not `vendored`. `tools/provenance/verify-census.sh` passes with the
   census unchanged at 63 files.
2. **No upstream byte moved.** `vendor/` is untouched; the drift gate re-verifies every
   authorized file's SHA-256 against the accepted registry.
3. **Derivation is by inheritance.** `contract VuxPoolDeployer is UniswapV3PoolDeployer` — the
   upstream `deploy()` CREATE2 semantics and the argument-free `parameters()` init-code pattern
   are inherited, not transcribed. Consequently `POOL_INIT_CODE_HASH` is unaffected:
   `tools/provenance/verify-init-code-hash.sh` reproduces
   `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` exactly, and
   `test/provenance/PoolInitCodeHash.t.sol` additionally re-checks the 22,728-byte creation-code
   length and the solc CBOR tail.
4. **The additions are VUX-original**, exactly the four the SDD enumerates (sdd.md:L194): the
   salted `msg.sender`-binding commitment gate, the one-shot latch, the Finding-4
   parameter-domain checks, and the permanently dead `owner()`.

**Authorized source surface unchanged.** No dependency was added; `remappings.txt` is untouched;
no v3-periphery file, import, or remapping exists (`verify-census.sh` §8 detector passes);
`UniswapV3Factory.sol` is neither vendored nor recreated. The SPDX gate confirms all 24 VUX-owned
Solidity files in the subject declare `GPL-3.0-or-later` with no invented copyright holder.

---

## Sources deliberately not consulted

For the Strategic Treasury, the classification engine, the distribution surface, and the LSG
boundary: no external protocol-treasury implementation, no external vault or receipt-share
standard implementation, no external strategy-registry or adapter framework, no external
reward-distributor or gauge implementation, and — specifically and by name in the accepted
authority, PROV-4 — the pinned external signal-governance repository. The `ILSGModule`
interface's single `view` was written from the FR-13 boundary text.

## Reproduction

```bash
bash tools/provenance/run-all.sh      # 8 gates + full suite, all fail-closed
```
