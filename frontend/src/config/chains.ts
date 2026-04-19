// DEV-007: All contracts on Settlement. Single chain config.
import { defineChain } from 'viem'
import type { ChainConfig } from '../types'

function makeViemChain(name: string, rpcUrl: string) {
  return defineChain({
    id: Number(import.meta.env.VITE_SETTLEMENT_EVM_CHAIN_ID || 1),
    name,
    nativeCurrency: { name: 'MIN', symbol: 'MIN', decimals: 6 },
    rpcUrls: { default: { http: [rpcUrl] } },
  })
}

// Localhost fallback for dev; production build logs a warning below
const SETTLEMENT_RPC = import.meta.env.VITE_SETTLEMENT_RPC ?? 'http://localhost:8545'
const SETTLEMENT_REST = import.meta.env.VITE_SETTLEMENT_REST ?? 'http://localhost:1317'

if (import.meta.env.PROD && SETTLEMENT_RPC.includes('localhost')) {
  console.error('VITE_SETTLEMENT_RPC points to localhost in production build — set a real RPC URL')
}

export const SETTLEMENT: ChainConfig = {
  chainId: import.meta.env.VITE_SETTLEMENT_CHAIN_ID || 'ghostpay-1',
  name: 'GhostPay Settlement',
  rpcUrl: SETTLEMENT_RPC,
  restUrl: SETTLEMENT_REST,
  viemChain: makeViemChain('GhostPay Settlement', SETTLEMENT_RPC),
}

export const TICK_INTERVAL_MS = 30_000
export const POLL_INTERVAL_MS = 5_000
