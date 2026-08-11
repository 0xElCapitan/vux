# VUX v1 OpenZeppelin v5.2.0 / Uniswap v3-core v1.0.0 Provenance Refreeze

**Date:** 2026-08-10
**Status:** `PROVENANCE_REFREEZE_CURRENT_ACCEPTED`
**Operator acceptance:** 2026-08-10 — `OPERATOR_ACCEPTANCE`
**Base authority (preserved, supplemented — not rewritten):** `vux-v1-licence-provenance-source-pin-freeze-2026-08.md` (SHA-256 `50c3584a1483b40ffb6391260a2bf42df32220c64724fdcc672ca62c01ace3a2`) and `vux-v1-source-registry-2026-08.json` (SHA-256 `6fc9fa81d80eda1f1017c6cb79f297b9a608150538e76ad97d8de1c8b5d2fe04`)
**Prior delta (preserved):** `vux-v1-strategic-treasury-provenance-boundary-delta-2026-08.md` (SHA-256 `5e1790276e290a08c58c1fe0accd40fc5d94b5a2ddc94dbb2c91aa90fce12ec3`) and `vux-v1-source-registry-strategic-treasury-delta-2026-08.json` (SHA-256 `79e2df97606027e020c2ec3100647dc60f4e7b53fcb3ab1f00128ba91df4b97f`)
**Machine-readable companion:** `vux-v1-source-registry-oz-v3-refreeze-2026-08.json`
**Selection evidence (not authorization):** accepted SDD v1.6.0 (`grimoires/loa/sdd.md`, SHA-256 `19241ed7db8a89b419e746463c6121f5b77c8237d760829e2f2604536c37392a`) and accepted PRD v2.0.0 (`grimoires/loa/prd.md`, SHA-256 `4e5cacf72d276377cb20897d9e1fe8aea721cc5edb2b0fd55e5cfde79ec89377`). Every pin, licence fact, and file identity below was **independently re-verified from primary upstream sources on 2026-08-10** — the SDD's selection was treated as a claim to check, never as source authorization.

---

## 1. Purpose, scope, and non-actions

This is the smallest authoritative refreeze necessary to lawfully support the accepted SDD's selected P0 smart-contract dependencies **before first import**: the exact OpenZeppelin Contracts v5.2.0 import surface and the exact Uniswap v3-core v1.0.0 vendored surface (pool implementation + libraries + deployer pattern + concrete interfaces), plus the toolchain pins and the `POOL_INIT_CODE_HASH` build constant those sources imply.

This node performed **no implementation**: nothing was imported, vendored, installed, or written into the VUX source tree; no Foundry configuration was created or modified; no commit/push/tag was made. The `POOL_INIT_CODE_HASH` reproduction ran in an isolated temporary workspace outside the repository.

Default-deny is preserved. A file not enumerated in §3/§4 remains unauthorized. No wildcard, directory-level, or entire-repository authorization exists anywhere in this refreeze, and no mutable reference (branch, tag name, `HEAD`, `latest`) is authority — the 40-character commits are the pins.

## 2. Independently verified immutable pins

Verification method (2026-08-10): `git ls-remote <canonical-url> refs/tags/<tag>` with `^{}` peel for annotated tags; a fresh isolated shallow clone at each source tag with `git rev-parse HEAD` equality against the expected commit; package identity read from the in-repo `package.json` at the pin; commit dates re-verified from clone metadata or the canonical repository via the GitHub API.

| repository | tag | tag kind | verified 40-char commit | commit date |
|---|---|---|---|---|
| `OpenZeppelin/openzeppelin-contracts` | `v5.2.0` | lightweight | `acd4ff74de833399287ed6b31b4debf6b2b35527` | 2025-01-09 |
| `Uniswap/v3-core` | `v1.0.0` | annotated (tag object `ef64f51d0f0dca5346c903484f3e6a771dd69d59`) | `e3589b192d0be27e100cd0daaf6c97204fdb1899` | 2021-05-04 |
| `ethereum/solidity` | `v0.7.6` | lightweight | `7338295feebfb3f044e265d5cf05ef1841b258b1` | 2020-12-16 |
| `ethereum/solidity` | `v0.8.28` | lightweight | `7893614a31fbeacd1966994e310ed4f760772658` | 2024-10-09 |
| `foundry-rs/foundry` | `v1.0.0` | lightweight | `8692e926198056d0228c1e166b1b6c34a5bed66c` | 2025-01-31 |
| `Uniswap/v3-periphery` *(evidence only — §7; zero code use)* | `v1.0.0` | annotated (tag object `268ceeba9686544f90db2593e700c59bf56971f2`) | `464a8a49611272f7349c970e0fadb7ec1d3c1086` | 2021-05-04 |

Every commit matches the accepted SDD §2.1 selection exactly. Package identities at the pins: `openzeppelin-solidity 5.2.0`; `@uniswap/v3-core 1.0.0` (package `license` field `BUSL-1.1`).

## 3. OpenZeppelin Contracts v5.2.0 — exact authorized import surface

**Licence evidence (primary):** repository root `LICENSE` at the pin (git blob `b2fee8f211650092ffdcbd519ef3ffbc1c258b8f`, SHA-256 `8b3fddff3cff904ab9bd7c48a9288fb08ab4f47b179c07af6df7886b12cb04d6`) is the MIT License, `Copyright (c) 2016-2024 Zeppelin Group Ltd`. Every authorized file below declares `SPDX-License-Identifier: MIT` (mechanical census). The verbatim notice is reproduced in `THIRD_PARTY_NOTICES.md` §6.1.

**Seed import surface (accepted SDD §2.1):** `contracts/token/ERC20/ERC20.sol`, `contracts/token/ERC20/extensions/ERC20Permit.sol`, `contracts/token/ERC20/IERC20.sol`, `contracts/token/ERC20/utils/SafeERC20.sol`, `contracts/access/AccessControl.sol`, `contracts/utils/ReentrancyGuard.sol`, `contracts/utils/math/Math.sol`.

**Authorized files — the complete, closed census (28 files).** This is the mechanically computed transitive import closure of the seed surface at commit `acd4ff74de833399287ed6b31b4debf6b2b35527` (7 seeds + 21 OZ-internal transitive imports). Identities are per-file at the pinned checkout.

| upstream path | git blob OID | SHA-256 (file bytes at pin) | SPDX |
|---|---|---|---|
| `contracts/access/AccessControl.sol` | `3e3341e9cfd62e7137f4dd4ea6445b43e4c619c1` | `1086a1ad3788972b885ff3f209da510615dde6214d46b29e1cd2a4924f66c06d` | MIT |
| `contracts/access/IAccessControl.sol` | `4c16a6ef75ca7686b374f5a3d13bc94fe0d796f0` | `c112f5c86fdc4e862f88d4f5694530342320923ebd5b5e7d9d8493550d337c2d` | MIT |
| `contracts/interfaces/IERC1363.sol` | `02de22859973a398a699ba415a57054c659ec78a` | `54f427f63724d9760211dfa9e0cc5d79d86c0724becd81f8e638e2e27b0e2669` | MIT |
| `contracts/interfaces/IERC165.sol` | `944dd0d59127e60f7b55fd8dacde9ea64f43b245` | `49abfb8fa26e3f1715fe05948a96e3762b805bd4a77d103eb40ba96b1acfa144` | MIT |
| `contracts/interfaces/IERC20.sol` | `21d5a41327566dac52adc0037d35d9177241eca4` | `cb42f0b4d269ba8ef2629c176a7f99bf4fb50837c92f45596b54822b26e3df4b` | MIT |
| `contracts/interfaces/IERC5267.sol` | `47a9fd5885563f1d65a77f0847bdd91bfed9d17a` | `efd1ebd1e04b6ef9c3b8781a097588f83da954323f438d54a71dc06508e6c7b8` | MIT |
| `contracts/interfaces/draft-IERC6093.sol` | `3227fd624fca8e3dc2ba54e672c550be7a158e5f` | `56380323009ef4a119d44550b910fde1bff9cedde8f7f4c690152c7629bc3338` | MIT |
| `contracts/token/ERC20/ERC20.sol` | `471908d6c1b8f7b108b774528eedafd4132d7794` | `c322867b0b30f6d5f791e5ab9af5e3f5ff1c8c127906748f6725e592a5f40719` | MIT |
| `contracts/token/ERC20/IERC20.sol` | `7d1019563f5af1dfe72a771bc4d5fac1ffc8afd9` | `30edf7394bab78d48b7db3a059248e1ea7c2c77d2ec0e37a13bb91415aafbe5a` | MIT |
| `contracts/token/ERC20/extensions/ERC20Permit.sol` | `3d36561a85f822a75a250b50daa445e0229da837` | `75f9f66db047b1413aa45538a53211e7b20479d74c3dd2657335bf4dc50b8811` | MIT |
| `contracts/token/ERC20/extensions/IERC20Metadata.sol` | `3c067ef401283b6ae369fcc275e4ef6371daa7d3` | `9e7c70ec72d2f7d592e23ea84f3852b04f91f6f644ce57e0263493046b36afb9` | MIT |
| `contracts/token/ERC20/extensions/IERC20Permit.sol` | `fc374368fd2bb8de71a7699e499f260ab32d1b8f` | `026aca1c8ee4574eb9719dca7dfc33e3e57a618715ae702a675e8a8c9ea1e82d` | MIT |
| `contracts/token/ERC20/utils/SafeERC20.sol` | `edac165bca5734c0c9ec1d7c565f1966934df689` | `8d3062e8831a07bab894607a7e6990f0b336024079ed5baaaae1f2b103e292ad` | MIT |
| `contracts/utils/Context.sol` | `4e535fe03c243f864568b8f4430c17c25dbadb47` | `847fda5460fee70f56f4200f59b82ae622bb03c79c77e67af010e31b7e2cc5b6` | MIT |
| `contracts/utils/Nonces.sol` | `37451ff93a595bc3626f2d582dc44e3d31cd95ce` | `9b4cbb85d1f5053c744e83302538eb643a713ffd14bc37665b224f1c66529339` | MIT |
| `contracts/utils/Panic.sol` | `e168824d34b3f0ba0be33317fb34b9e74fc148b6` | `270fc8401c1a13fae6a7a4a2dd6e381b95d658896701e51f0d3e2688acab3dec` | MIT |
| `contracts/utils/ReentrancyGuard.sol` | `a95fb512f31d44755a811ad66f8e2de4b602266e` | `32fbb1c908ec1b4de85cc1bb10091aebd5816ffe80dfdd5ca5e084fbea67a462` | MIT |
| `contracts/utils/ShortStrings.sol` | `fb8bde516685af590c53dd1576b4f96a917d54cf` | `c5970e9c77c9a797941fcb9ab8c9a5d0b1227c610a919ee8a04ba061e6881873` | MIT |
| `contracts/utils/StorageSlot.sol` | `aebb10524a2c82aa78ceb8394e5f3c1b0e5abeea` | `75704538dcb223239280c6726d9a31cf769a7816718517c997fc7d63bdb70778` | MIT |
| `contracts/utils/Strings.sol` | `0360b4cabb3cfd6abd7b97ad08a4fd7fa33d9009` | `1d47b183ce3217de32c41cf6034281a783f41380ca99d1ca043509018b656165` | MIT |
| `contracts/utils/cryptography/ECDSA.sol` | `6493f56338ac22d133456cc439fc651b9459e54c` | `0964ddd02f4a7a8cf9ba130e3aeead588ca3d425d5bc13cc4221358c69108ed0` | MIT |
| `contracts/utils/cryptography/EIP712.sol` | `f15a67bd9b5a0e8a1e98d463dec80387dfd6349c` | `e7f41ef62494c6c26ddaaac0f2790fa365b635e7c5aaacbeafba3067574e38d7` | MIT |
| `contracts/utils/cryptography/MessageHashUtils.sol` | `e1cbccb65ecc7b8870462651e7f0878ee4d1fc5c` | `93e4c09f9c65d37a14d796601b67a67fc918e16957a6328261f8635e136adf76` | MIT |
| `contracts/utils/introspection/ERC165.sol` | `9fbce0447e77f71b80bbfe9514178c0ceb1532ce` | `7fdc4dc9e3872f6a4c1ec9cfa9583a1fc18ccd7a416397a6e698bd5bbf92f32b` | MIT |
| `contracts/utils/introspection/IERC165.sol` | `719ec358659d3bb92f2c6de3ca77ed7aad249d90` | `7c5c3f98ab876991e7dd34b84d41137e836306eb9f36f6386a631f5be3f5d6d4` | MIT |
| `contracts/utils/math/Math.sol` | `85a420b1a7b262af6555743fc0a0b2d485f2bde7` | `68cf79a637995d5ed243c4a5856b42a5e134ee8786a05034e24d75927fc40ebc` | MIT |
| `contracts/utils/math/SafeCast.sol` | `b345ede1e6994a12d8ca5ba4b6e87401952cb116` | `9769274bf53f26a7c7896c526ea1980dc9bea5bf5c2a5fd04870008c4afc1de9` | MIT |
| `contracts/utils/math/SignedMath.sol` | `7c97aa4c22da6567126a82c6949ec39e363ea891` | `1ed50b1056af886752f0fb48a0165d381e69bb4a4b18b893b066dc144a7e08d7` | MIT |

**Authorization terms:**

- Exact-files-only; the census is **closed**: importing any OpenZeppelin path outside this table requires a new operator-accepted refreeze.
- Files must land byte-identical to the recorded blob OIDs/SHA-256s regardless of installation mechanism (git submodule at the pin, vendored copy, or package install), CI-verified; upstream files are never modified; upstream SPDX headers are retained verbatim.
- Permitted use: import/compilation within the VUX Solidity `=0.8.28` unit for the accepted SDD's contracts.
- MIT is GPLv3-compatible; the exact release's copyright and permission notice is preserved in `THIRD_PARTY_NOTICES.md` and survives conveyance of the combined GPL work.

## 4. Uniswap v3-core v1.0.0 — exact authorized vendored surface

**Licence evidence (primary):** repository root `LICENSE` at the pin (git blob `075a13ae390e521a9ccee36929e42725ed8ddf57`, SHA-256 `85c5cbc5be388d8bb38d8618de93c96e247ae5af20eb79dbafc1fb5b13b57b54`) is the **Business Source License 1.1** with these parameters, quoted from the file:

- **Licensor:** `Uniswap Labs`
- **Licensed Work:** `Uniswap V3 Core` — "The Licensed Work is (c) 2021 Uniswap Labs"
- **Additional Use Grant:** "Any uses listed and defined at v3-core-license-grants.uniswap.eth"
- **Change Date:** "The earlier of 2023-04-01 or a date specified at v3-core-license-date.uniswap.eth"
- **Change License:** "GNU General Public License v2.0 or later"

**Change-Date determination:** the Change Date parameter is *"the earlier of"* a fixed calendar date (2023-04-01) and an ENS-published date — an ENS record can only accelerate the change, never delay it. 2023-04-01 precedes this node's date (2026-08-10), so per the BUSL terms ("Effective on the Change Date … the Licensor hereby grants you rights under the terms of the Change License") **every BUSL-1.1 file at this pin is now governed by GPL-2.0-or-later, unconditionally and regardless of ENS state**. The Additional Use Grant is not relied on for anything.

**Seed surface (accepted SDD §1.4/§2.1 — implementation, not merely interfaces):** `contracts/UniswapV3Pool.sol`, `contracts/UniswapV3PoolDeployer.sol`, `contracts/NoDelegateCall.sol`.

**Authorized files — the complete, closed census (32 files).** This is the mechanically computed transitive import closure of the three implementation seeds at commit `e3589b192d0be27e100cd0daaf6c97204fdb1899`: 3 implementation files, all 16 libraries, and the 13 concrete interface files the implementation and the VUX integration mechanically require (pool interface + its 6 sub-interfaces, deployer interface, factory interface, 3 callback interfaces, minimal ERC20). The accepted SDD's directory-level interface description is hereby replaced by this exact enumeration — **no wildcard survives into authority**.

| upstream path | git blob OID | SHA-256 (file bytes at pin) | upstream SPDX | current licence basis |
|---|---|---|---|---|
| `contracts/NoDelegateCall.sol` | `5411979dcb6457f59b770d87f4ab7129d4cabd71` | `c2b03bbf6ae73415e9f60fb2bcdad1ee9dbb3ab1f27f9b12384c44d11a5624e0` | BUSL-1.1 | **GPL-2.0-or-later** (Change Date passed) |
| `contracts/UniswapV3Pool.sol` | `9e0982127248a69e3bf054049c7db966497793f9` | `d515775b7f3ffe921dd70aca86b8bad16280fa4c122425d82b4dbea4dc564a7a` | BUSL-1.1 | **GPL-2.0-or-later** (Change Date passed) |
| `contracts/UniswapV3PoolDeployer.sol` | `02bfd53547614f59dc50d09ad81003c5b1ecb918` | `1e27540bc60c4dccff5add8a04da61b7b30ee0c6b1fd25ff6806fec855db6cd1` | BUSL-1.1 | **GPL-2.0-or-later** (Change Date passed) |
| `contracts/interfaces/IERC20Minimal.sol` | `c303265a3b0d5a62d4d8a7adc1715990ad972947` | `bb0bf574bdfd637eb7d3c0869e8170314d5aac37df8e86cd3ca808f828c7c22a` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/IUniswapV3Factory.sol` | `540cfdc68167776e12d54f3a66765656af2bab26` | `17c72e89a7d0eecca7929ca08d97f46e80930ef7024e4ccbc7b294c588477107` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/IUniswapV3Pool.sol` | `56df0500dfb7fbb6df832fe96a9d7e77fb143c7d` | `b0f97121de74f3c916503f6ec37fa1ba196affd1cc02157e47ab00125dde91fe` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/IUniswapV3PoolDeployer.sol` | `72096c1ff597f8541f78763455fb53bcdc77ac4d` | `48908460f444abc497b261e38a38540effecbf5c99d17e60d849f1d0acfb1fe6` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/callback/IUniswapV3FlashCallback.sol` | `18e54c4e12cc471449b6e003bdee85360787ef5a` | `612135b515e651db56cd80191cd56c0b982eaae954c5b1c4d1dc111f8968d5b8` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/callback/IUniswapV3MintCallback.sol` | `85447e84f9b6493eb9699086ed3be2edc52467a0` | `4dbecbcec83e4f5609d72309f40be3eac554f8517ed46e6345bd35069c9bbc23` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/callback/IUniswapV3SwapCallback.sol` | `9f183b22a7016eae4d036db15077bc791cb8fb04` | `171a9a692e71b6d532df655695b0b672bd8ea5dcca3b3363131700b45b0171c6` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/pool/IUniswapV3PoolActions.sol` | `44fb61c24aaf14e4a767ee6eece840e807b3c35b` | `7fc763acbf5e7044d88cae4a6ed7b1c99b5268d647ae794ba5ee1085060e6a2c` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol` | `eda3a0089de2e0ad257d9daebcf65619b63f2b44` | `9f670bdfed3a283e0557b208a5d4bc561afd2df771d67c4368dddaae2dc1b6e3` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/pool/IUniswapV3PoolEvents.sol` | `9d915dde934fc7a0430195f29bb2172c47783a3d` | `2c2b798ca4288dfdf746bca8516b4e725b79ca6636af3d38a5a64801e50020a7` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/pool/IUniswapV3PoolImmutables.sol` | `c9beb151e3309f0d59664c400d3e41275bdf2e48` | `ac6332f7e174db7fa3852a6c5ae3da3bd013e72c2ff8fa1cf2ec37f6916e2951` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/pool/IUniswapV3PoolOwnerActions.sol` | `2395ed321df4092acadd99b67530d7650fb3858c` | `5f4cd982d6abe55237bc770da3b667f96edf048c230cfe3d7f6309c92cc0e205` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/interfaces/pool/IUniswapV3PoolState.sol` | `620256c3118ccd3897f1b2ac82529dc93729a14b` | `d8d3937703d08d95f7f867a0f49c2aa73c3f3ef5508a54d431e829295f5175ea` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/libraries/BitMath.sol` | `3a7216c7bd5e9d124957c7f7e487dafff7c8855c` | `32f71ea9156f55572a72efb0b2a913df88de66ff33d042043fb3e51a6050a557` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/libraries/FixedPoint128.sol` | `6d6948b106003cf35f8f877b7913cbc933133ed9` | `cfc3aef8851f183492547dccc168bf72398fba2aad4c4d9d4784f542a8ccda34` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/libraries/FixedPoint96.sol` | `63b42c294e821eb038793b7f1afb9ae0427f0691` | `219deb88ffbcdefa482be35051db586378e8523062bee592dd2c5fa7fb47ebd6` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/libraries/FullMath.sol` | `8688a1773ffbb5ec93d3abbe983f8c16141f9139` | `54087aee268a6938a85a408d7b14481b5c2c956c21508d5583f1bf48ec6d69ba` | MIT | MIT |
| `contracts/libraries/LiquidityMath.sol` | `d5e23032e8b9323de3df2b8d71d9bcc516cc5d6e` | `84d20a16d5346f6ec4c12dff4df23dda5d46e52d33f18aaaaac2e9e36ce4a072` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/libraries/LowGasSafeMath.sol` | `dbc817c2ec806775b7c9b213c6db0dffe00ea8cd` | `394107ff2dbbaded5612452af5e77b4af9d0871b096c1514b0ea659b862fc46f` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/libraries/Oracle.sol` | `3f6b3f32c99b82960c0fffd82340b845a03b1496` | `eea86662877614f800344bbe432098f9edf55735f5d1c9474ebd64b55097771b` | BUSL-1.1 | **GPL-2.0-or-later** (Change Date passed) |
| `contracts/libraries/Position.sol` | `1c67c7f279ff9dcf7d6bdaff12a5d3b1b5336a97` | `a9130c72e3adb7d3fa10ee5050fc9375d6119a8250125fe7daacec94450be21d` | BUSL-1.1 | **GPL-2.0-or-later** (Change Date passed) |
| `contracts/libraries/SafeCast.sol` | `a8ea22987877b615fcf3a557512b240eff1b77c7` | `9aed494b56d3dd16b7d6535583ded2cdfb03dc80aaa919347b13d35fd597e8bf` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/libraries/SqrtPriceMath.sol` | `685f485da43402235c3a9ce7fd85a49597b6373a` | `ddd62e3a94346248677f30f1ab009ef015e71e4b8696dcca890eeabc9dc6c149` | BUSL-1.1 | **GPL-2.0-or-later** (Change Date passed) |
| `contracts/libraries/SwapMath.sol` | `ee176fbee4ae2fb2ba7da4ddd00391fe6b685f39` | `d6cb9a153be4ea9fb2377ef88641ef7979b5cee6933162f1b732d0289e26e1b6` | BUSL-1.1 | **GPL-2.0-or-later** (Change Date passed) |
| `contracts/libraries/Tick.sol` | `13d34284942923f226ecbe84adc913df17f38523` | `749121625ab364e653971fae786a9c8e0859c8327e746d9edd999ae9d16f3d71` | BUSL-1.1 | **GPL-2.0-or-later** (Change Date passed) |
| `contracts/libraries/TickBitmap.sol` | `3c43585771d48b7b1868fd1b09212ec115088d1a` | `bd7a17c5134f0718eb7d856ddfc58d8347d32a8f661bed53aa3ad17c9aea09ba` | BUSL-1.1 | **GPL-2.0-or-later** (Change Date passed) |
| `contracts/libraries/TickMath.sol` | `378e44528caeb7fa0ce2f86b8a39f6d0785a0925` | `83cf64b2ca84001effd16e007b49bac5359143b6c3132bfe42907b2426a0c5f5` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/libraries/TransferHelper.sol` | `25d6309028b79fcdeddd7435d642b5e11d8fe707` | `f15b94bc000ee68e434c3ff4c28696c3f5bc23222bd6249744a7228b063e267b` | GPL-2.0-or-later | GPL-2.0-or-later |
| `contracts/libraries/UnsafeMath.sol` | `f62f84676fa39f98b4ae1f7a073fc767ecf78aaa` | `4d02353eb503e3111e25bd50104ac9b279f99e88d848e455262a3fbeb55c50e7` | GPL-2.0-or-later | GPL-2.0-or-later |

Tally: BUSL-1.1 × 9 (pool, deployer, NoDelegateCall, Oracle, Position, SqrtPriceMath, SwapMath, Tick, TickBitmap), GPL-2.0-or-later × 22 (all 13 interfaces + 9 libraries), MIT × 1 (FullMath).

**`IUniswapV3Factory.sol` note:** the pinned pool imports the factory *interface* for its `owner()`-gated functions (`setFeeProtocol`/`collectProtocol`), so the interface file is mechanically required and authorized; the factory **implementation** (`contracts/UniswapV3Factory.sol`) remains excluded (§8) — `VuxPoolDeployer` exposes `owner() == address(0)` permanently, so those gates are forever dead on the canonical pool.

**Vendoring posture (binding):**

- Upstream v3-core files land **byte-identical** to the recorded blob OIDs/SHA-256s; CI fails closed on any drift.
- Upstream SPDX headers are retained verbatim — including the `BUSL-1.1` headers, preserved as historical fact; the Change-Date conversion is recorded here and in `THIRD_PARTY_NOTICES.md`, never edited into upstream files.
- The vendored pool implementation is never edited. All VUX-specific behavior — commitment gate, one-shot consumption, parameter-domain checks, permanent `owner() == address(0)` — lives only in VUX-owned source.
- The vendored tree compiles as a separate Solidity `=0.7.6` unit (§6); interface files (pragma `>=0.5.0`) may additionally be imported by the `=0.8.28` unit.
- Compiled pool creation bytecode is compared against the verified upstream result via `POOL_INIT_CODE_HASH` (§7); CI fails closed on mismatch.

**`VuxPoolDeployer.sol` provenance/SPDX disposition (binding):** per the accepted SDD §1.4 it **derives from the pinned `UniswapV3PoolDeployer`** — subclassing/adopting the upstream deployer pattern with exact upstream `deploy` semantics (CREATE2 with salt `keccak256(abi.encode(token0, token1, fee))`, argument-free init code via the `parameters()` pattern). It is therefore a **derivative of the upstream deployer pattern and must never be described as wholly VUX-original**; only the commitment gate, one-shot, domain checks, and `owner()==address(0)` are VUX-original additions. SPDX: `GPL-3.0-or-later` (GPLv3 selected under the or-later option of the Change License now governing the upstream file), with a **mandatory provenance header**: upstream repository/path/commit `e3589b19…`/blob `02bfd535…`; original licence BUSL-1.1, governed by GPL-2.0-or-later since the 2023-04-01 Change Date; Uniswap Labs credit; prominent dated VUX modification notice; pointer to `THIRD_PARTY_NOTICES.md`. If implementation ends up textually adapting upstream deployer code rather than inheriting it, the same derivative treatment applies a fortiori. A bare `GPL-3.0-or-later` header with no upstream provenance is prohibited on this file.

## 5. Licence analysis and project-licence compatibility determination

| source class | licence state at consumption | GPL-3.0-or-later compatibility |
|---|---|---|
| OpenZeppelin authorized files (28) | MIT (per-file SPDX + root LICENSE) | Compatible; notice preserved in TPN §6.1 |
| v3-core BUSL-1.1 files (9) | **GPL-2.0-or-later** via Change License (Change Date 2023-04-01 passed — §4) | Compatible; VUX selects GPLv3 under the or-later option (same treatment as the existing Euler FeeFlow precedent) |
| v3-core GPL-2.0-or-later files (22) | GPL-2.0-or-later (per-file SPDX) | Compatible; GPLv3 selected under the or-later option |
| v3-core MIT file (1: `FullMath.sol`) | MIT (per-file SPDX) | Compatible |

**Determination (per-item 10):** no source combination in this refreeze requires a licence posture different from the accepted VUX project licence. The combined VUX work — VUX-original `GPL-3.0-or-later` code, Miner-derived `MIT AND GPL-3.0-or-later` code, MIT OpenZeppelin dependencies, and the GPL-2.0-or-later-governed v3-core vendored tree — remains conveyable under **`GPL-3.0-or-later`** with all upstream notices preserved. GPL corresponding-source obligations attach on conveyance exactly as the base freeze already records.

**SPDX treatment (completing the base-freeze table for this surface):**

| file condition | SPDX identifier |
|---|---|
| Unmodified vendored v3-core file | retain upstream SPDX verbatim (`BUSL-1.1` / `GPL-2.0-or-later` / `MIT`) |
| Unmodified imported OpenZeppelin file | retain `MIT` |
| VUX-original file that only imports authorized OZ/v3-core files (no upstream text copied) | `GPL-3.0-or-later` |
| `VuxPoolDeployer.sol` | `GPL-3.0-or-later` + mandatory upstream provenance header (§4 — never bare) |
| Any VUX file materially adapting v3-core text | `GPL-3.0-or-later` + full derivative provenance header (dated modification notice, upstream identity) |

No document or header may invent a copyright holder. The only holder statements carried by this refreeze are the upstream ones quoted verbatim: `Copyright (c) 2016-2024 Zeppelin Group Ltd` (OZ LICENSE) and "The Licensed Work is (c) 2021 Uniswap Labs" (v3-core LICENSE).

## 6. Toolchain pins (verified; recorded for reproducibility — toolchain is not imported source)

| tool | unit | tag → verified commit | binding rule |
|---|---|---|---|
| solc | VUX-original + Miner-derived code, exact pragma `=0.8.28` | `v0.8.28` → `7893614a31fbeacd1966994e310ed4f760772658` | — |
| solc | vendored v3-core unit + `VuxPoolDeployer`, exact pragma `=0.7.6` | `v0.7.6` → `7338295feebfb3f044e265d5cf05ef1841b258b1` | **The vendored v3-core compilation unit MUST remain `=0.7.6`. Upstream 0.7 wrapping arithmetic MUST NOT be ported to 0.8.x.** |
| Foundry (forge/anvil/cast) | build/test/deploy harness | `v1.0.0` → `8692e926198056d0228c1e166b1b6c34a5bed66c` | pinned via `foundry.toml` + CI at Sprint 1 |

The official solc 0.7.6 compiler build self-reports `0.7.6+commit.7338295f` — the compiler distribution and the pinned source commit corroborate each other.

## 7. `POOL_INIT_CODE_HASH` — verified value and reproduction recipe

**Verified value:**

```text
POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54
```

**Derivation rule:** `POOL_INIT_CODE_HASH = keccak256(creationCode(UniswapV3Pool))`. The pinned pool's init code is argument-free (its constructor reads `parameters()` from `msg.sender`, the deployer), so the hash is a pure build constant. Canonical pool address = `create2(vuxPoolDeployer, keccak256(abi.encode(token0, token1, fee)), POOL_INIT_CODE_HASH)`.

**Independent reproduction (2026-08-10, isolated workspace — nothing entered the VUX repository):**

| build setting | value (all bytecode-affecting settings enumerated) |
|---|---|
| compiler | official solc `0.7.6+commit.7338295f` (= pinned `ethereum/solidity` commit `7338295f…`) |
| sources | exactly the 32 authorized files of §4, bytes from the pinned checkout `e3589b19…` (line endings unmangled: `core.autocrlf=false`) |
| optimizer | **enabled**, `runs = 800` |
| metadata | `bytecodeHash: 'none'` (upstream comment: "we want all generated code to be deterministic") |
| EVM target | `istanbul` (solc 0.7.6 default; upstream `hardhat.config.ts` sets no override) |
| viaIR | not applicable (does not exist in 0.7.6) |
| remappings / source layout | none needed — all v3-core imports are relative; source keys are `contracts/…` paths |
| CBOR appendage | solc default; produced creation-code tail `a164736f6c6343000706000a` = CBOR `{solc: 0.7.6}`, mechanically confirming `bytecodeHash: 'none'` |

Settings source: upstream `hardhat.config.ts` at the pin (verbatim: `optimizer {enabled: true, runs: 800}`, `metadata {bytecodeHash: 'none'}`, no per-file overrides). Result: creation bytecode 22,728 bytes; `keccak256` = the value above.

**Cross-confirmation:** the identical constant is published upstream in pinned `Uniswap/v3-periphery` v1.0.0 @ `464a8a49611272f7349c970e0fadb7ec1d3c1086`, `contracts/libraries/PoolAddress.sol` line 6 (git blob `60de3852b1425b21a52e583cc4f87c33859339f2`, SHA-256 `484aa68ddecd9ca3bf1a9c872da13b736271c8e1ce1f2ac795b190d26210981b`). Two independent chains — fresh compile from pinned source vs. the canonical upstream-published derivation constant — agree byte-for-byte. The periphery pin is **evidence only**; it authorizes zero code use.

**Sprint-1 binding obligations (fail-closed):**

1. The Foundry profile for the `=0.7.6` vendored unit MUST reproduce `UniswapV3Pool` creation bytecode whose `keccak256` equals this value (`solc 0.7.6`, optimizer enabled, `optimizer_runs = 800`, `evm_version = "istanbul"`, `bytecode_hash = "none"`, solc-default CBOR appendage). CI fails closed on mismatch **before any deployment code is accepted**.
2. Genesis wiring, the closing self-verification sweep, and the wiring tests use exactly this constant (accepted SDD §1.4).
3. Any change to compiler version or any bytecode-affecting setting invalidates this hash and requires a new refreeze entry.

## 8. Exclusions and preserved boundaries

Explicitly **excluded** unless a new operator decision is later made:

- `Uniswap/v3-core` `contracts/UniswapV3Factory.sol` (factory implementation — rejected topology; the interface is authorized per §4);
- **all** `Uniswap/v3-periphery` source (the §7 evidence pin authorizes zero code use);
- every other `Uniswap/v3-core` path not in the §4 census (tests, audits, echidna specs, build scripts);
- every OpenZeppelin path not in the §3 census.

Preserved unchanged from the base freeze and prior delta:

- the Miner Manifold direct-reuse allowlist remains **exactly** the three pinned files (`contracts/Rig.sol`, `contracts/Unit.sol`, `contracts/interfaces/IUnit.sol` @ `bcffbf1e…`) — not expanded;
- `Heesho/liquid-signal-governance` was **not opened, fetched, or consulted** during this node and remains `DEFERRED_NOT_V1` (with `Voter.sol`/`Bribe.sol` `PROHIBITED_PENDING_CLEARANCE`);
- gumball6900, give.fun, Olympus v3, and Olympus docs remain reference-only/prohibited exactly as recorded;
- default deny, full-SHA-only pin policy, and the refreeze requirement for any newer revision.

Operator-reserved values are untouched: Q-3 (Safe signers/threshold), Q-4 (jurisdiction), Q-6 (RH native-token/`WETH.deposit` fact), fee tier, tick spacing, genesis USD conversion, Strategic allocation policy, revenue/signaler percentages, ROOT/GIGA admission, strategy caps, LSG activation timing, and every R-1…R-14 value remain where the accepted SDD leaves them. No deployment-time fact is pulled into source authority.

## 9. Deferred off-chain provenance obligations (recorded so they cannot be forgotten)

This refreeze deliberately covers **only** the P0 smart-contract surface. The following remain under the identical fail-closed rule — exact immutable pins recorded in an operator-accepted refreeze **before their first import/use** in the applicable later sprint: **ponder** (0.8.x family), **Next.js** 15.1.4 family + **React** 19.0.0, **viem** 2.21.x / **wagmi** 2.14.x, **Playwright** 1.49.x, **PostgreSQL** 16.4 (deployment fact under the same recording discipline), **slither** 0.10.x and any additional CI/static-analysis toolchain.

## 10. Acceptance

Operator acceptance was recorded on 2026-08-10, authorizing exactly the source surface enumerated in §3/§4 above and no more — it does not authorize arbitrary dependency expansion. This acceptance activates the §3/§4 authorizations, makes the `THIRD_PARTY_NOTICES.md` §6.1/§6.2 additions current, and unblocks `/sprint-plan`. Nothing has been imported, vendored, or installed by this node; that remains a later-sprint action gated by the Sprint-1 binding obligations of §7.

## 11. Authority disposition

The base licence/provenance freeze and base JSON registry remain authoritative for all existing pins, allowlists, and permissions; the Strategic-Treasury delta remains authoritative for the corrected-surface clean-source classifications. This refreeze is additive: it **completes** the base registry's OpenZeppelin family entry (`SDD_SELECTION_REQUIRED_BEFORE_CODING` → the exact v5.2.0 selection of §3) and **adds** the v3-core dependency that the base registry's `future_refreeze_required_for` rule required to arrive exactly this way. No predecessor authority file is rewritten, no historical attribution is removed, and no precedence above the licence/pin layer changes: FREEZE/SPEC supersessions, accepted PRD, and accepted SDD govern product and architecture; this refreeze governs only source provenance and licence state for the enumerated files.

**STOP. Operator acceptance is recorded 2026-08-10. `/sprint-plan` is the authorized next node.**
