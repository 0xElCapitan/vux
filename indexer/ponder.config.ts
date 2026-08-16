// ponder configuration — VUX v1 off-chain replica.
//
// Every address and the start block are supplied by environment, never frozen
// here: the deployed identities are R-14 deployment-time founder facts
// (prd.md:L335) and this sprint must not record them. The defaults point at a
// local anvil so the reconstruction harness can run against a real chain.

import { createConfig } from "ponder";
import { http } from "viem";
import { RigAbi, HardReserveAbi, StrategicTreasuryAbi, VUXAbi } from "./abis/vux-events.mjs";

const rpc = process.env.PONDER_RPC_URL_1 ?? "http://127.0.0.1:8545";
const startBlock = Number(process.env.VUX_START_BLOCK ?? 0);

const required = (name: string): `0x${string}` => {
  const v = process.env[name];
  if (!v) {
    // Fail closed rather than index a zero address and report an empty, healthy-
    // looking replica — a silently empty truth surface is worse than no surface.
    throw new Error(`${name} is not set. The indexer refuses to start against an unknown address.`);
  }
  return v as `0x${string}`;
};

export default createConfig({
  networks: {
    // A real viem transport, not a descriptor. The previous
    // `{ kind: "http", url } as never` type-checked only because the cast erased
    // the mismatch: ponder calls the transport, and a plain object is not
    // callable. The `as never` is what let a non-functional config ship.
    vux: { chainId: Number(process.env.VUX_CHAIN_ID ?? 31337), transport: http(rpc) },
  },
  contracts: {
    Rig: { network: "vux", abi: RigAbi, address: required("VUX_RIG_ADDRESS"), startBlock },
    HardReserve: { network: "vux", abi: HardReserveAbi, address: required("VUX_RESERVE_ADDRESS"), startBlock },
    StrategicTreasury: {
      network: "vux",
      abi: StrategicTreasuryAbi,
      address: required("VUX_TREASURY_ADDRESS"),
      startBlock,
    },
    VUX: { network: "vux", abi: VUXAbi, address: required("VUX_TOKEN_ADDRESS"), startBlock },
  },
});
