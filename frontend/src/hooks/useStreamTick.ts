import { useRef, useCallback, useEffect, useState } from 'react'
import { encodeFunctionData } from 'viem'
import { TICK_INTERVAL_MS } from '../config/chains'
import { STREAM_SENDER_ADDRESS, STREAM_SENDER_ABI } from '../config/contracts'

interface UseStreamTickOptions {
  streamId: string
  enabled: boolean
  senderAddress: string
  submitTxBlock: (params: { msgs: any[] }) => Promise<any>
}

export function useStreamTick({ streamId, enabled, senderAddress, submitTxBlock }: UseStreamTickOptions) {
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const isSendingRef = useRef(false)
  const lastSentRef = useRef<number>(0)
  const [isSending, setIsSending] = useState(false)
  const [tickCount, setTickCount] = useState(0)
  const [lastTickTime, setLastTickTime] = useState<number | null>(null)

  const sendTick = useCallback(async () => {
    const now = Date.now()
    if (isSendingRef.current) return
    if (now - lastSentRef.current < TICK_INTERVAL_MS * 0.9) return // debounce StrictMode double-invoke (27s guard for 30s interval)
    lastSentRef.current = now
    isSendingRef.current = true
    setIsSending(true)
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

      setTickCount((c) => c + 1)
      setLastTickTime(Date.now())
    } catch (err) {
      console.error('Tick failed:', err)
    } finally {
      isSendingRef.current = false
      setIsSending(false)
    }
  }, [streamId, senderAddress, submitTxBlock])

  useEffect(() => {
    if (!enabled || !streamId) {
      if (intervalRef.current) clearInterval(intervalRef.current)
      return
    }

    sendTick()

    intervalRef.current = setInterval(sendTick, TICK_INTERVAL_MS)
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current)
      isSendingRef.current = false
    }
  }, [enabled, streamId, sendTick])

  const stop = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current)
      intervalRef.current = null
    }
  }, [])

  return { tickCount, lastTickTime, isSending, stop }
}
