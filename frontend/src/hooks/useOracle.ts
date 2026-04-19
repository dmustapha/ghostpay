import { useQuery } from '@tanstack/react-query'
import { SETTLEMENT } from '../config/chains'
import type { OraclePrice } from '../types'

export function useOraclePrice(pairId: string = 'INIT/USD') {
  return useQuery({
    queryKey: ['oracle', pairId],
    queryFn: async (): Promise<OraclePrice | null> => {
      try {
        const res = await fetch(`${SETTLEMENT.restUrl}/slinky/oracle/v1/get_price?currency_pair_id=${pairId}`)
        if (!res.ok) {
          if (pairId === 'INIT/USD') {
            const fallbackRes = await fetch(`${SETTLEMENT.restUrl}/slinky/oracle/v1/get_price?currency_pair_id=ETH/USD`)
            if (!fallbackRes.ok) return null
            const fallbackData = await fallbackRes.json()
            return parseOracleResponse(fallbackData)
          }
          return null
        }
        const data = await res.json()
        return parseOracleResponse(data)
      } catch {
        return null
      }
    },
    refetchInterval: 30_000,
    staleTime: 15_000,
  })
}

function parseOracleResponse(data: any): OraclePrice {
  return {
    price: BigInt(data.price?.price || '0'),
    timestamp: Number(data.price?.block_timestamp || '0'),
    decimal: Number(data.decimals || 8),
  }
}

// tokenDecimals: 6 for umin (cosmos micro-denom), 18 for EVM-native
export function formatUsdValue(amountWei: bigint, price: OraclePrice | null | undefined, tokenDecimals = 6): string {
  if (!price || price.price === 0n) return '$?.??'
  const usdRaw = (amountWei * price.price) / (10n ** BigInt(price.decimal))
  const usdFloat = Number(usdRaw) / 10 ** tokenDecimals
  return `$${usdFloat.toFixed(2)}`
}
