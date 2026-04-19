import { useState, useEffect, useRef } from 'react'

interface StreamCounterProps {
  current: bigint
  rate: bigint
  active: boolean
  totalAmount?: bigint
}

export function StreamCounter({ current, rate, active, totalAmount }: StreamCounterProps) {
  const [displayValue, setDisplayValue] = useState(current)
  const startTimeRef = useRef(Date.now())
  const baseValueRef = useRef(current)

  useEffect(() => {
    baseValueRef.current = current
    startTimeRef.current = Date.now()
    setDisplayValue(current)
  }, [current])

  useEffect(() => {
    if (!active || rate === 0n) return

    const interval = setInterval(() => {
      const elapsedMs = Date.now() - startTimeRef.current
      const increment = (rate * BigInt(elapsedMs)) / 30_000n
      let value = baseValueRef.current + increment
      if (totalAmount !== undefined && value > totalAmount) {
        value = totalAmount
      }
      setDisplayValue(value)
    }, 100)

    return () => clearInterval(interval)
  }, [active, rate, totalAmount])

  const formatted = (Number(displayValue) / 1e6).toFixed(6)

  return (
    <span className="text-white font-mono tabular-nums font-medium">
      {formatted} <span className="text-gray-500 text-xs">MIN</span>
    </span>
  )
}
