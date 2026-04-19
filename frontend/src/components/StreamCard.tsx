import type { StreamView } from '../types'
import { StreamCounter } from './StreamCounter'
import { formatUsdValue } from '../hooks/useOracle'
import type { OraclePrice } from '../types'

interface StreamCardProps {
  stream: StreamView
  type: 'sent' | 'received'
  oraclePrice?: OraclePrice | null
}

export function StreamCard({ stream, type, oraclePrice }: StreamCardProps) {
  const progress = stream.totalAmount > 0n
    ? Number((stream.amountSent * 100n) / stream.totalAmount)
    : 0

  const remaining = stream.endTime - Math.floor(Date.now() / 1000)
  const timeLeft = remaining > 0 ? formatDuration(remaining) : 'Completed'

  return (
    <div className={`card-hover p-5 ${stream.active ? 'glow-ghost' : ''}`}>
      <div className="flex items-center justify-between mb-4">
        <span className={stream.active ? 'badge-active' : 'badge-ended'}>
          {stream.active ? 'Streaming' : 'Ended'}
        </span>
        <span className="text-xs text-gray-500 font-mono">{timeLeft}</span>
      </div>

      <div className="space-y-3">
        <div className="flex justify-between items-center text-sm">
          <span className="text-gray-500">{type === 'sent' ? 'To' : 'From'}</span>
          <span className="text-gray-300 font-mono text-xs bg-gray-800/60 px-2 py-0.5 rounded-md">
            {type === 'sent'
              ? stream.receiver.slice(0, 14) + '...'
              : stream.sender?.slice(0, 14) + '...'}
          </span>
        </div>

        <div className="flex justify-between items-center text-sm">
          <span className="text-gray-500">Streamed</span>
          <StreamCounter
            current={stream.amountSent}
            rate={stream.ratePerTick}
            active={stream.active}
            totalAmount={stream.totalAmount}
          />
        </div>

        <div className="flex justify-between items-center text-sm">
          <span className="text-gray-500">Total</span>
          <span className="text-white font-medium">
            {formatAmount(stream.totalAmount)} MIN
            {oraclePrice && (
              <span className="text-gray-500 ml-1.5 text-xs">{formatUsdValue(stream.totalAmount, oraclePrice)}</span>
            )}
          </span>
        </div>

        {/* Progress bar */}
        <div className="pt-1">
          <div className="w-full bg-gray-800/80 rounded-full h-1.5 overflow-hidden">
            <div
              className="h-full rounded-full transition-all duration-1000 ease-out bg-gradient-to-r from-ghost-600 to-ghost-400"
              style={{ width: `${Math.min(progress, 100)}%` }}
            />
          </div>
          <div className="flex justify-between mt-1.5">
            <span className="text-[10px] text-gray-600">{progress}%</span>
            <span className="text-[10px] text-gray-600">{formatAmount(stream.amountSent)} / {formatAmount(stream.totalAmount)}</span>
          </div>
        </div>
      </div>
    </div>
  )
}

function formatAmount(microAmount: bigint): string {
  return (Number(microAmount) / 1e6).toFixed(4)
}

function formatDuration(seconds: number): string {
  if (seconds >= 3600) {
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    return `${h}h ${m}m`
  }
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}m ${s}s`
}
