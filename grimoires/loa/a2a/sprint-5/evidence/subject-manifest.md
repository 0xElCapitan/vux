# Sprint-5 implementation subject — manifest and fingerprint

**Node:** Sprint 5 implementation (`/implement sprint-5`)
**Worktree:** `C:\Users\0x007\vux-sprint-5`, branch `sprint-5`
**Baseline:** `cf0108109e428da0483b8470726f9e48ee740777` (`master == origin/master == sprint-5` at
node entry, clean tree, zero commits ahead)
**Purpose:** an exact-tree identity for `/review-sprint sprint-5` and the later audit, and a
clean, *mechanically derived* separation between (A) what this node changed and (B) the State
Zone / lifecycle material it wrote or touched.

---

## How this manifest was derived

Not from a list of files the node expected to have touched. The set is read out of git, and the
partition into (A) and (B) is a pure path-prefix rule with no per-file judgement in it:

```bash
BASE=cf0108109e428da0483b8470726f9e48ee740777

# R: the complete repository delta — tracked modifications AND untracked files.
{ git diff --name-only "$BASE" -- . ; git ls-files --others --exclude-standard ; } \
  | LC_ALL=C sort -u > R.txt

grep -E '^(src/|test/|script/|foundry\.toml$|remappings\.txt$)' R.txt | LC_ALL=C sort > A.txt
grep -E '^(grimoires/|\.beads/|\.run/)'                          R.txt | LC_ALL=C sort > B.txt
```

Starting from `R` rather than from `A` is the point: a file this node changed and forgot to
report cannot be absent from `R`, because `R` is what the repository says happened.

### Exhaustiveness, proven in both directions

| direction | check | result |
|---|---|---|
| nothing omitted | `A ∪ B == R` — every observed delta is classified | **OK** (12 + 11 == 23) |
| nothing double-counted | `A ∩ B == ∅` | **OK** (0) |
| nothing phantom | every row of `A` exists on disk | **OK** (12/12) |

```bash
cat A.txt B.txt | LC_ALL=C sort -u | diff - R.txt && echo "OK  A u B == R"
comm -12 A.txt B.txt | wc -l                      # 0
while read -r f; do [ -f "$f" ] || echo "MISSING $f"; done < A.txt
```

Observed **at node entry** (before any lifecycle artifact was written): `R` = 23, `A` = 12,
`B` = 11.

Re-run **at node exit**, after `reviewer.md`, this manifest, the scope slice, `a2a/index.md`, and
`NOTES.md` were written: `R` = 34, `A` = **12 (unchanged)**, `B` = 22, all three checks still OK,
and the fingerprint recomputes to the same
`37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a`. A reviewer re-running the
commands will see the exit numbers; that `B` grew and `A` did not is the property the partition
exists to make visible — lifecycle bookkeeping cannot move the tree under review.

---

## A. The implementation subject — 12 files

**Fingerprint:** `37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a`

Reproduce exactly (msys/Git-Bash binary mode; the leading `*` in each row is `sha256sum`'s
binary marker and is part of the hashed bytes):

```bash
xargs -a A.txt sha256sum | LC_ALL=C sort -k2 | sha256sum
```

| sha256 | path | status |
|---|---|---|
| `603b1c186c3b40298a10e3310dddf1fe956b271e9e61c310547ac351a8549cdd` | `script/PolVyrfE2E.s.sol` | new |
| `8b601ee157ed7fe02f616c55e529468380d2712d2f52b7466cd69e0bee2f46dd` | `src/StrategicTreasury.sol` | **modified** |
| `b2f697911a33d02d4e5651e5d6d14aec95586c81819effcd1a768a492943e947` | `test/mocks/MockCallbackPool.sol` | new |
| `4ad83f103815e23e01c38ba6b31a84cff65575774086aa081316416e28f4521d` | `test/mocks/MockSwapper.sol` | new |
| `5dcd5dd04b4fbcaea86b5a648d26b83342ddc641ab01ed0af0eeec02ffdafe30` | `test/treasury/PolConduct.t.sol` | new |
| `b0847da61376d1b2627cfe47d6f37bf9383e675ac5090c90cd658354fd71651d` | `test/treasury/PolFailureBehaviors.t.sol` | new |
| `55a94bd2ed4935a787c2ad92531d28f6aae6c454bb4fb249938f49dcef71eaf3` | `test/treasury/PolFixture.sol` | new |
| `8c85faf3bbbe607c0552870e8a6b9b27d7a01a03b9887d08193574b73ca5122f` | `test/treasury/PolInvariantHandler.sol` | new |
| `f0273e4e301f309a46c9f28e9f171d3d9fe9ea59244ff9c70fe475865c8126eb` | `test/treasury/PolInvariants.t.sol` | new |
| `7860566c243b58da2b76e6d561b512506c74e5d1ee8a2fe3d179c5a34b03f0d1` | `test/treasury/TreasuryCallbackAuth.t.sol` | new |
| `0a1bbe7ce7b6765f914e21f226c8e62da9548cad23a385422059e9793de55ab2` | `test/treasury/TreasuryPol.t.sol` | new |
| `954470de1269778a9877fec1700d4b9dd1ccc0724eaba74b86a595478a53da43` | `test/treasury/TreasurySurface.t.sol` | **modified** |

### The two modifications, and why each was necessary

- **`src/StrategicTreasury.sol`** — the sprint's subject. Additive only: the POL sleeve, the two
  callbacks, the two cost-basis cells, the one-shot context, and their constants/errors/events.
  No Sprint-4 function body was altered, no accepted behaviour was changed, and no Sprint-4
  finding was reopened (see `reviewer.md` §"Sprint-4 carry-forward").
- **`test/treasury/TreasurySurface.t.sol`** — the accepted-surface array grew from 44 to 53
  entries, plus its docstring. This file is a **closed-world** assertion (every accepted entry
  present *and* every present entry accepted), so it is designed to fail when the external
  surface changes; updating it is how the new surface gets accepted rather than a workaround.
  The nine additions are exactly the SDD §5.2.5 POL surface and nothing else.

### What is NOT in the subject, and matters

**`foundry.toml` is unchanged.** Sprint 5 required no compilation-unit change in either
direction, so the twice-observed profile-inheritance hazard had no new opportunity to fire. It
was still verified rather than assumed, by asking the toolchain for its *resolved* settings
rather than reading the file:

```
$ FOUNDRY_PROFILE=v3core forge config
solc = "0.7.6"   optimizer = true   optimizer_runs = 800
evm_version = "istanbul"   bytecode_hash = "none"   via_ir = false
```

— byte-for-byte the accepted refreeze §7 set, and `tools/provenance/verify-init-code-hash.sh`
reproduces `POOL_INIT_CODE_HASH = 0xe34f199b…b8b54` and finds it equal to the accepted constant.

**No new dependency.** `vendor/` is untouched, `remappings.txt` is untouched, and the only
imports the POL sleeve added are already-accepted census members: the vendored v3-core
`IUniswapV3Pool` interface (already imported by this file in Sprint 4) and OpenZeppelin
`SafeCast`. No v3-periphery, no position manager, no router, no external callback helper, and no
copied third-party helper code entered the repository. The `HITL_REQUIRED —
NEW_DEPENDENCY_PROVENANCE_GATE` stop was therefore never reached.

---

## B. State Zone / lifecycle material — 11 paths

Written or touched by the node's own lifecycle bookkeeping, and deliberately **outside** the
fingerprint so that review and audit hash a tree that does not move when a report is edited.

| path | role |
|---|---|
| `.beads/issues.jsonl` | task lifecycle: epic `vux-2jw` and tasks `vux-221`, `vux-24x`, `vux-1uw`, `vux-7tj`, `vux-7z7`, `vux-kgg` moved `open → in_progress → closed` |
| `.beads/.br_history/issues.*.jsonl` (5) | beads' own auto-flush snapshots, one per `br` mutation |
| `.beads/.br_history/issues.*.jsonl.meta.json` (5) | their sidecars |

Written after this manifest was computed, and therefore also outside the fingerprint by
construction: `grimoires/loa/a2a/sprint-5/reviewer.md`,
`grimoires/loa/a2a/sprint-5/sprint-5-scope.md`,
`grimoires/loa/a2a/sprint-5/evidence/subject-manifest.md` (this file),
`grimoires/loa/a2a/index.md`, `grimoires/loa/NOTES.md`.

**Not touched by this node:** `grimoires/loa/prd.md`, `grimoires/loa/sdd.md`,
`grimoires/loa/sprint.md` (`4531a508…7f4bebf` — unchanged from baseline; the Sprint-5 checkboxes
are **not** ticked, because ticking them is an acceptance act), `grimoires/loa/ledger.json`,
`docs/authority/**`, and every prior sprint's `a2a/` directory.

---

## C. Scope slice

`sprint-5-scope.md` (`829f34378232c98b96145013b7f1d7e474009d0d37c620cf851a11b318834a7e`) is the
byte-exact Sprint-5 section of `sprint.md` (lines 353–407), extracted with

```bash
sed -n '353,407p' grimoires/loa/sprint.md
```

and used as the scoped input to the AC verification walk in `reviewer.md`.
