import { useRef, useEffect, useState, useCallback } from 'react'
import { encodeFunctionData } from 'viem'
import { TICK_INTERVAL_MS } from '../config/chains'
import { STREAM_SENDER_ADDRESS, STREAM_SENDER_ABI } from '../config/contracts'

import type { CosmosMsg } from '../types'

interface UseStreamTickOptions {
  streamId: string
  enabled: boolean
  senderAddress: string
  submitTxBlock: (params: { msgs: CosmosMsg[] }) => Promise<unknown>
}

export function useStreamTick({ streamId, enabled, senderAddress, submitTxBlock }: UseStreamTickOptions) {
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const isSendingRef = useRef(false)
  const lastSentRef = useRef<number>(0)
  const [isSending, setIsSending] = useState(false)
  const [tickCount, setTickCount] = useState(0)
  const [lastTickTime, setLastTickTime] = useState<number | null>(null)

  useEffect(() => {
    if (!enabled || !streamId) return

    // Local cancelled flag — scoped to THIS effect instance.
    // Prevents setState on stale closures after cleanup.
    let cancelled = false

    const doTick = async () => {
      const now = Date.now()
      if (isSendingRef.current) return
      if (now - lastSentRef.current < TICK_INTERVAL_MS * 0.9) return
      lastSentRef.current = now
      isSendingRef.current = true
      if (!cancelled) setIsSending(true)
      try {
        const calldata = encodeFunctionData({
          abi: STREAM_SENDER_ABI,
          functionName: 'sendTick',
          args: [streamId as `0x${string}`],
        })

        await submitTxBlock({
          msgs: [{
            typeUrl: '/minievm.evm.v1.MsgCall',
            value: {
              sender: senderAddress,
              contract_addr: STREAM_SENDER_ADDRESS,
              input: calldata,
              value: '0',
            },
          }],
        })

        if (!cancelled) {
          setTickCount((c) => c + 1)
          setLastTickTime(Date.now())
        }
      } catch (err) {
        console.error('Tick failed:', err)
      } finally {
        isSendingRef.current = false
        if (!cancelled) setIsSending(false)
      }
    }

    doTick()
    intervalRef.current = setInterval(doTick, TICK_INTERVAL_MS)

    return () => {
      cancelled = true
      if (intervalRef.current) clearInterval(intervalRef.current)
      isSendingRef.current = false
    }
  }, [enabled, streamId, senderAddress, submitTxBlock])

  const stop = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current)
      intervalRef.current = null
    }
  }, [])

  return { tickCount, lastTickTime, isSending, stop }
}
