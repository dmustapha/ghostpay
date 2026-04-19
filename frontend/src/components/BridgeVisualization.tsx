import { useState, useEffect, useRef } from 'react'

interface Packet {
  id: number
  progress: number
  phase: 'hop1' | 'hop2'
}

interface BridgeVisualizationProps {
  activeStreamCount: number
  lastTickTime: number | null
}

export function BridgeVisualization({ activeStreamCount, lastTickTime }: BridgeVisualizationProps) {
  const [packets, setPackets] = useState<Packet[]>([])
  const nextIdRef = useRef(0)

  useEffect(() => {
    if (!lastTickTime) return
    const id = nextIdRef.current++
    setPackets((prev) => [...prev, { id, progress: 0, phase: 'hop1' }])
  }, [lastTickTime])

  useEffect(() => {
    const interval = setInterval(() => {
      setPackets((prev) =>
        prev
          .map((p) => {
            const newProgress = p.progress + 1.5
            if (newProgress >= 100 && p.phase === 'hop1') {
              return { ...p, progress: 0, phase: 'hop2' as const }
            }
            return { ...p, progress: newProgress }
          })
          .filter((p) => !(p.phase === 'hop2' && p.progress >= 100))
      )
    }, 50)
    return () => clearInterval(interval)
  }, [])

  const isActive = activeStreamCount > 0

  return (
    <div className="flex flex-col items-center justify-center gap-3 px-2 py-4 min-w-[56px]">
      {/* Top label */}
      <div className="text-[10px] uppercase tracking-widest text-gray-500 font-medium">
        Settlement
      </div>

      {/* Bridge tube */}
      <div className="relative w-10 flex-1 min-h-[200px] max-h-[400px]">
        {/* Background track */}
        <div className={`absolute inset-0 rounded-full border transition-colors duration-500 ${
          isActive ? 'border-ghost-700/50 bg-ghost-950/40' : 'border-gray-800/60 bg-gray-900/40'
        }`} />

        {/* Center node (settlement) */}
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-10">
          <div className={`w-5 h-5 rounded-full border-2 transition-all duration-500 ${
            isActive
              ? 'border-ghost-400 bg-ghost-600 shadow-lg shadow-ghost-500/40 animate-glow'
              : 'border-gray-600 bg-gray-700'
          }`} />
        </div>

        {/* Divider line */}
        <div className="absolute left-0 right-0 top-1/2 h-px bg-gray-700/40" />

        {/* Sender → Settlement (top half) */}
        <div className="absolute inset-0 top-0 bottom-1/2 overflow-hidden rounded-t-full">
          {packets
            .filter((p) => p.phase === 'hop1')
            .map((p) => (
              <div
                key={p.id}
                className="absolute left-1/2 -translate-x-1/2"
                style={{ top: `${p.progress}%` }}
              >
                <div className="w-3.5 h-3.5 rounded-full bg-ghost-400 shadow-lg shadow-ghost-400/60" />
                <div className="absolute inset-0 w-3.5 h-3.5 rounded-full bg-ghost-400/30 animate-ping" />
              </div>
            ))}
        </div>

        {/* Settlement → Receiver (bottom half) */}
        <div className="absolute inset-0 top-1/2 bottom-0 overflow-hidden rounded-b-full">
          {packets
            .filter((p) => p.phase === 'hop2')
            .map((p) => (
              <div
                key={p.id}
                className="absolute left-1/2 -translate-x-1/2"
                style={{ top: `${p.progress}%` }}
              >
                <div className="w-3.5 h-3.5 rounded-full bg-emerald-400 shadow-lg shadow-emerald-400/60" />
                <div className="absolute inset-0 w-3.5 h-3.5 rounded-full bg-emerald-400/30 animate-ping" />
              </div>
            ))}
        </div>

        {/* Idle pulse when active but no packets */}
        {isActive && packets.length === 0 && (
          <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
            <div className="w-8 h-8 rounded-full bg-ghost-500/10 animate-pulse-slow" />
          </div>
        )}
      </div>

      {/* Bottom label */}
      <div className={`text-xs font-medium transition-colors ${
        isActive ? 'text-ghost-400' : 'text-gray-600'
      }`}>
        {activeStreamCount > 0 ? `${activeStreamCount} stream${activeStreamCount > 1 ? 's' : ''}` : 'Idle'}
      </div>
    </div>
  )
}
