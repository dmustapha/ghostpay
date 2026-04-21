import { useState, useCallback } from 'react'
import { encodeFunctionData } from 'viem'
import { STREAM_RECEIVER_ABI, STREAM_RECEIVER_ADDRESS } from '../config/contracts'
import type { CosmosMsg } from '../types'

interface UseClaimOptions {
  callerAddress: string | undefined
  submitTxBlock: (params: { msgs: CosmosMsg[] }) => Promise<unknown>
}

export function useClaim({ callerAddress, submitTxBlock }: UseClaimOptions) {
  const [isClaiming, setIsClaiming] = useState(false)
  const [claimError, setClaimError] = useState<string | null>(null)

  const claim = useCallback(async () => {
    if (!callerAddress || isClaiming) return
    setIsClaiming(true)
    setClaimError(null)
    try {
      await submitTxBlock({
        msgs: [{
          typeUrl: '/minievm.evm.v1.MsgCall',
          value: {
            sender: callerAddress,
            contract_addr: STREAM_RECEIVER_ADDRESS,
            input: encodeFunctionData({
              abi: STREAM_RECEIVER_ABI,
              functionName: 'claim',
              args: [],
            }),
            value: '0',
          },
        }],
      })
    } catch (err) {
      console.error('Claim failed:', err)
      setClaimError(err instanceof Error ? err.message : 'Claim failed')
    } finally {
      setIsClaiming(false)
    }
  }, [callerAddress, isClaiming, submitTxBlock])

  return { claim, isClaiming, claimError }
}
