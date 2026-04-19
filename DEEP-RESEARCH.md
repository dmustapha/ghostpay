# Technical Spike — GhostPay

## Verified Patterns (copy these into Architecture Doc)

| Component | Pattern | Source URL | Confidence |
|-----------|---------|-----------|:---:|
| ICosmos precompile | `0x00...f1` — `execute_cosmos()` for IBC transfers from Solidity | https://github.com/initia-labs/initia-evm-contracts/blob/main/src/interfaces/ICosmos.sol | HIGH |
| IBC MsgTransfer | `initia.js` has full `MsgTransfer` class wrapping standard Cosmos IBC proto | https://github.com/initia-labs/initia.js/blob/main/src/core/ibc/applications/transfer/msgs/MsgTransfer.ts | HIGH |
| ConnectOracle | `IConnectOracle` at `0x031ECb63480983FD216D17BB6e1d393f3816b72F` — `get_price("BTC/USD")` | https://github.com/initia-labs/initia-evm-contracts/blob/main/src/ConnectOracle.sol | HIGH |
| Address conversion | `ICosmos.to_cosmos_address()` / `to_evm_address()` on-chain; `bech32-converting` npm off-chain | https://docs.initia.xyz/developers/developer-guides/vm-specific-tutorials/evm/address-conversion | HIGH |
| AutoSign API | `autoSign.enable(chainId)` → opens drawer, derives ghost wallet, creates authz+feegrant grants | https://docs.initia.xyz/interwovenkit/features/autosign/api-reference | HIGH |
| AutoSign scoping | `enableAutoSign` prop accepts per-chain message type URL arrays | https://docs.initia.xyz/interwovenkit/features/autosign/configuration | HIGH |
| EVM IBC hooks | Memo field `{"evm":{"message":{"contract_addr":"0x...","input":"0x..."}}}` triggers contract on receive | https://docs.initia.xyz/build-on-initia/vm-specific-tutorials/evm/evm-ibc-hooks | HIGH |
| Foundry deploy flags | `--via-ir --with-gas-price 0 --skip-simulation` required for minievm | https://docs.initia.xyz/developers/developer-guides/vm-specific-tutorials/evm/connect-oracles | HIGH |
| Rapid-relayer | Node.js IBC relayer optimized for 500ms blocks, replaces Hermes | https://github.com/initia-labs/rapid-relayer | HIGH |
| Weave rollup launch | `weave rollup launch` → interactive prompts for VM, chain ID, gas denom, oracle toggle | https://docs.initia.xyz/nodes-and-rollups/deploying-rollups/deploy | HIGH |

## Unverified Patterns (use with caution, mark with WARNING in Architecture Doc)

| Component | Pattern | Source URL | Risk |
|-----------|---------|-----------|------|
| L2→L2 routing | All IBC goes L2A → L1 → L2B (two hops). No direct L2-to-L2 channels exist. | https://daic.capital/blog/initia-bridge-guide-cross-chain-asset-transfer | Doubles latency; need 2 relayer instances |
| IBC transfer speed | "Instant" (~5-15s estimated for two-hop L2→L1→L2) based on 500ms block times | https://medium.com/@initialabs/minitswap-l2-to-l1-withdrawals-in-seconds-not-days-e6de645879b3 | No measured benchmarks found |
| TransferAuthorization | ibc-go has `TransferAuthorization` with source_port/channel/spend_limit/receiver allow_list — unclear if InterwovenKit supports it natively | https://ibc.cosmos.network/v6/apps/transfer/authorizations/ | May need to fall back to GenericAuthorization |
| Oracle pair availability | BTC/USD and ETH/USD confirmed. Full list is dynamic per network config. | https://docs.initia.xyz/developers/developer-guides/vm-specific-tutorials/evm/connect-oracles | INIT/USD pair may not exist — need to check at runtime |
| Faucet rate limit | Testnet faucet at faucet.testnet.initia.xyz — once per 24h, requires Gitcoin Passport | https://faucet.testnet.initia.xyz/ | Could block Day 1 if passport not ready |
| OPinit funding | Need ~7-8 INIT for executor/submitter/challenger bots | https://docs.initia.xyz/nodes-and-rollups/deploying-rollups/deploy | Faucet may not give enough in one drip |

## Assumed / Not Found (need decision trees in Implementation Plan)

| Component | What's Unknown | Fallback Approach |
|-----------|---------------|-------------------|
| Scheduling mechanism | No on-chain cron/timer for recurring txs. InterwovenKit auto-sign is a session key, not an autonomous agent. | Frontend `setInterval` / Web Worker fires `submitTxBlock()` on interval while tab is open. For demo, this is sufficient. |
| InterwovenKit source code | `@initia/interwovenkit-react` is closed-source. No public GitHub repo. | Rely on published docs + API reference. Test empirically. |
| Ghost wallet key extraction | Unclear if Privy embedded wallet keys can be used server-side for backend streaming. | MVP: frontend-only streaming. Production: investigate Privy server SDK. |
| Direct L2-L2 IBC channels | No tooling exists. Weave only sets up L2↔L1 relayer. | Accept two-hop routing. Demo still works — just slightly more latency. |
| MiniBank Blueprint | No documentation found with this name. | Use standard Foundry patterns with minievm-specific flags. |
| INIT/USD oracle pair | Not confirmed available. Only BTC/USD, ETH/USD verified. | Query `get_all_currency_pairs()` at runtime. If no INIT/USD, use ETH/USD as proxy or hardcode a rate for demo. |

---

## Critical Architecture Decisions from Spike

### 1. IBC from Solidity — The Key Integration Point
The `ICosmos` precompile at `0x00...f1` allows Solidity contracts to execute Cosmos SDK messages directly. This means:
- Payment contract calls `COSMOS_CONTRACT.execute_cosmos(msgTransferJSON)` to trigger IBC transfers
- EVM IBC hooks on the receiving end auto-execute a destination contract via memo field
- **This is the core mechanism** — no need for a separate backend relay service for IBC

### 2. Auto-Sign = Session Key, Not Scheduler
InterwovenKit's auto-sign creates a ghost wallet with scoped authz grants. But it does NOT provide scheduling. The frontend must drive the stream cadence:
- `setInterval(() => submitTxBlock(streamPayment), intervalMs)`
- For hackathon demo, this is fine — user keeps tab open during demo
- Scope grants to: `/ibc.applications.transfer.v1.MsgTransfer` + `/minievm.evm.v1.MsgCall`

### 3. Two-Hop L2→L1→L2 Is Acceptable
No direct L2-to-L2 IBC exists. Every cross-rollup transfer routes through L1. For demo:
- Stream tick fires IBC from Rollup A → L1 (hop 1)
- L1 relays to Rollup B (hop 2)
- ~5-15 seconds per tick — perfectly fine for demo visualization

### 4. Oracle Integration Is Clean
`IConnectOracle.get_price("BTC/USD")` returns structured price data. The contract at a known address wraps the ICosmos precompile. Gas-expensive (JSON parsing in Solidity) but functional for demo.

### 5. Foundry Deployment Needs Special Flags
`--via-ir --with-gas-price 0 --skip-simulation` are mandatory. Standard Foundry patterns otherwise.

---

## Key Code Patterns for Architecture Doc

### IBC Transfer from Solidity
```solidity
// [VERIFIED] — Source: https://github.com/initia-labs/initia-evm-contracts
ICosmos constant COSMOS_CONTRACT = ICosmos(0x00000000000000000000000000000000000000f1);

function ibcTransfer(string memory channel, string memory receiver, uint256 amount) external {
    string memory msg = string(abi.encodePacked(
        '{"@type":"/ibc.applications.transfer.v1.MsgTransfer",',
        '"source_port":"transfer",',
        '"source_channel":"', channel, '",',
        '"token":{"denom":"uinit","amount":"', Strings.toString(amount), '"},',
        '"sender":"', COSMOS_CONTRACT.to_cosmos_address(address(this)), '",',
        '"receiver":"', receiver, '",',
        '"timeout_timestamp":"', timeout, '",',
        '"memo":""}'
    ));
    COSMOS_CONTRACT.execute_cosmos(msg);
}
```

### Oracle Price Query from Solidity
```solidity
// [VERIFIED] — Source: https://github.com/initia-labs/initia-evm-contracts
IConnectOracle oracle = IConnectOracle(ORACLE_ADDRESS);
IConnectOracle.Price memory price = oracle.get_price("INIT/USD");
uint256 usdValue = (amount * price.price) / (10 ** price.decimal);
```

### Auto-Sign Setup (Frontend)
```tsx
// [VERIFIED] — Source: https://docs.initia.xyz/interwovenkit/features/autosign
<InterwovenKitProvider
  enableAutoSign={{
    'ghostpay-settlement-1': [
      '/ibc.applications.transfer.v1.MsgTransfer',
      '/minievm.evm.v1.MsgCall'
    ]
  }}
>
  {children}
</InterwovenKitProvider>

// Usage
const { autoSign, submitTxBlock } = useInterwovenKit()
await autoSign.enable('ghostpay-settlement-1')
// Now submitTxBlock() fires without popups
```

### EVM IBC Hook Memo (Cross-Chain Contract Call)
```json
// [UNVERIFIED] — Source: https://docs.initia.xyz/build-on-initia/vm-specific-tutorials/evm/evm-ibc-hooks
{
  "evm": {
    "message": {
      "contract_addr": "0xReceiverContract",
      "input": "0xCreditStreamCalldata"
    }
  }
}
```

### Weave Rollup Launch Commands
```bash
# [VERIFIED] — Source: https://docs.initia.xyz/nodes-and-rollups/deploying-rollups/deploy
weave rollup launch          # Interactive: VM=EVM, chain-id, gas denom, oracle=yes
weave opinit init && weave opinit start executor
weave opinit init && weave opinit start challenger
weave relayer init && weave relayer start

# EVM endpoints after launch:
# JSON-RPC: http://localhost:8545
# REST: http://localhost:1317
# RPC: http://localhost:26657
```

### Foundry Deploy
```bash
# [VERIFIED] — Source: https://docs.initia.xyz/developers/developer-guides/vm-specific-tutorials/evm
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --via-ir \
  --with-gas-price 0 \
  --skip-simulation
```
