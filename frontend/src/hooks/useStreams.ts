// DEV-007: All contracts on Settlement (single chain)
import { useQuery } from '@tanstack/react-query'
import { createPublicClient, http } from 'viem'
import { SETTLEMENT, POLL_INTERVAL_MS } from '../config/chains'
import {
  STREAM_SENDER_ADDRESS,
  STREAM_RECEIVER_ADDRESS,
  STREAM_SENDER_ABI,
  STREAM_RECEIVER_ABI,
} from '../config/contracts'
import type { StreamView } from '../types'

const BATCH_SIZE = 5

async function batchMap<T, R>(items: T[], fn: (item: T) => Promise<R>, concurrency: number): Promise<R[]> {
  const results: R[] = []
  for (let i = 0; i < items.length; i += concurrency) {
    const batch = items.slice(i, i + concurrency)
    const batchResults = await Promise.all(batch.map(fn))
    results.push(...batchResults)
  }
  return results
}

const settlementClient = createPublicClient({
  chain: SETTLEMENT.viemChain,
  transport: http(SETTLEMENT.rpcUrl),
})

/** Normalize address to 0x-prefixed EVM format. Bech32 addresses are not valid
 *  for on-chain view calls — InterwovenKit should provide EVM addresses, but
 *  guard against bech32 being passed by mistake. */
function ensureEvmAddress(addr: string): `0x${string}` {
  if (addr.startsWith('0x')) return addr as `0x${string}`
  // Bech32 passed where EVM expected — log warning, return as-is (will fail at RPC level
  // with a clear error rather than silently querying the wrong address)
  console.warn(`Expected EVM address but got "${addr.slice(0, 12)}..." — ensure wallet provides EVM format`)
  return addr as `0x${string}`
}

export function useSentStreams(senderAddress: string | undefined) {
  return useQuery({
    queryKey: ['sentStreams', senderAddress],
    queryFn: async (): Promise<StreamView[]> => {
      if (!senderAddress) return []
      const evmAddr = ensureEvmAddress(senderAddress)
      const ids = await settlementClient.readContract({
        address: STREAM_SENDER_ADDRESS as `0x${string}`,
        abi: STREAM_SENDER_ABI,
        functionName: 'getSenderStreams',
        args: [evmAddr],
      }) as `0x${string}`[]

      const streams = await batchMap(ids, async (id) => {
        const info = await settlementClient.readContract({
          address: STREAM_SENDER_ADDRESS as `0x${string}`,
          abi: STREAM_SENDER_ABI,
          functionName: 'getStreamInfo',
          args: [id],
        }) as {
          streamId: `0x${string}`; sender: string; senderCosmos: string;
          receiver: string; destChannel: string;
          totalAmount: bigint; amountSent: bigint; ratePerTick: bigint;
          startTime: bigint; endTime: bigint; active: boolean;
        }
        return {
          streamId: id,
          sender: info.sender,
          senderCosmos: info.senderCosmos,
          receiver: info.receiver,
          destChannel: info.destChannel,
          totalAmount: info.totalAmount,
          amountSent: info.amountSent,
          ratePerTick: info.ratePerTick,
          startTime: Number(info.startTime),
          endTime: Number(info.endTime),
          active: info.active,
        } as StreamView
      }, BATCH_SIZE)
      return streams
    },
    enabled: !!senderAddress,
    refetchInterval: POLL_INTERVAL_MS,
    staleTime: 10_000,
  })
}

export function useClaimableBalance(receiverAddress: string | undefined) {
  return useQuery({
    queryKey: ['claimable', receiverAddress],
    queryFn: async (): Promise<bigint> => {
      if (!receiverAddress) return 0n
      const evmAddr = ensureEvmAddress(receiverAddress)
      const result = await settlementClient.readContract({
        address: STREAM_RECEIVER_ADDRESS as `0x${string}`,
        abi: STREAM_RECEIVER_ABI,
        functionName: 'getClaimable',
        args: [evmAddr],
      })
      return result as bigint
    },
    enabled: !!receiverAddress,
    refetchInterval: POLL_INTERVAL_MS,
  })
}

// receiverStreamIds is indexed by (address, uint256) — no simple "get all" getter
// For demo, claimable balance is sufficient
