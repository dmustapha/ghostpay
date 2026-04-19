// DEV-007: All contracts on Settlement — demo still shows split-screen for narrative
import { useState } from 'react'
import { encodeFunctionData } from 'viem'
import { useSentStreams, useClaimableBalance } from '../hooks/useStreams'
import { useOraclePrice, formatUsdValue } from '../hooks/useOracle'
import { BridgeVisualization } from '../components/BridgeVisualization'
import { StreamCard } from '../components/StreamCard'
import { STREAM_RECEIVER_ABI, STREAM_RECEIVER_ADDRESS } from '../config/contracts'

interface DemoViewProps {
  senderAddress: string | undefined
  receiverAddress: string | undefined
  lastTickTime: number | null
  callerAddress: string | undefined
  submitTxBlock: (params: { msgs: any[] }) => Promise<any>
}

export function DemoView({ senderAddress, receiverAddress, lastTickTime, callerAddress, submitTxBlock }: DemoViewProps) {
  const { data: sentStreams } = useSentStreams(senderAddress)
  const { data: claimable } = useClaimableBalance(receiverAddress)
  const { data: oraclePrice } = useOraclePrice()
  const [isClaiming, setIsClaiming] = useState(false)
  const [claimError, setClaimError] = useState<string | null>(null)

  const activeStreams = sentStreams?.filter((s) => s.active) || []

  return (
    <div className="min-h-[calc(100vh-120px)]">
      {/* Header */}
      <div className="text-center mb-8">
        <h2 className="text-2xl font-bold bg-gradient-to-r from-ghost-300 via-ghost-400 to-emerald-400 bg-clip-text text-transparent">
          Live Payment Stream
        </h2>
        <p className="text-sm text-gray-500 mt-1.5">
          Real-time money movement through the settlement layer
        </p>
      </div>

      {/* Split-screen layout */}
      <div className="grid grid-cols-[1fr_auto_1fr] gap-6 items-stretch" style={{ minHeight: '420px' }}>
        {/* Left: Sender Panel */}
        <div className="card p-6 flex flex-col">
          <div className="flex items-center gap-2.5 mb-5">
            <div className="w-2.5 h-2.5 rounded-full bg-ghost-500 animate-pulse-slow" />
            <h3 className="text-sm font-semibold uppercase tracking-wider text-gray-400">Sender</h3>
            <span className="text-[10px] text-gray-600 font-mono ml-auto">
              {senderAddress ? senderAddress.slice(0, 8) + '...' : 'Not connected'}
            </span>
          </div>

          {activeStreams.length > 0 ? (
            <div className="space-y-4 flex-1">
              {activeStreams.map((stream) => (
                <StreamCard
                  key={stream.streamId}
                  stream={stream}
                  type="sent"
                  oraclePrice={oraclePrice}
                />
              ))}
            </div>
          ) : (
            <div className="flex-1 flex items-center justify-center">
              <div className="text-center">
                <div className="text-3xl mb-3 opacity-30">G</div>
                <p className="text-gray-600 text-sm">No active streams</p>
                <p className="text-gray-700 text-xs mt-1">Create a stream to see it flow</p>
              </div>
            </div>
          )}
        </div>

        {/* Center: Bridge */}
        <BridgeVisualization
          activeStreamCount={activeStreams.length}
          lastTickTime={lastTickTime}
        />

        {/* Right: Receiver Panel */}
        <div className="card p-6 flex flex-col">
          <div className="flex items-center gap-2.5 mb-5">
            <div className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse-slow" />
            <h3 className="text-sm font-semibold uppercase tracking-wider text-gray-400">Receiver</h3>
            <span className="text-[10px] text-gray-600 font-mono ml-auto">
              {receiverAddress ? receiverAddress.slice(0, 8) + '...' : ''}
            </span>
          </div>

          <div className="space-y-5 flex-1">
            {/* Claimable balance card */}
            <div className={`rounded-2xl p-5 border transition-all duration-500 ${
              claimable && claimable > 0n
                ? 'bg-emerald-950/30 border-emerald-800/40 glow-green'
                : 'bg-gray-800/40 border-gray-800/60'
            }`}>
              <p className="text-xs font-medium text-gray-400 uppercase tracking-wider mb-2">Claimable Balance</p>
              <p className="text-4xl font-bold font-mono tabular-nums text-emerald-400">
                {claimable ? (Number(claimable) / 1e6).toFixed(6) : '0.000000'}
              </p>
              <p className="text-sm text-gray-500 mt-1">
                MIN
                {oraclePrice && claimable !== undefined && claimable > 0n && (
                  <span className="ml-2">{formatUsdValue(claimable, oraclePrice)}</span>
                )}
              </p>
            </div>

            {/* Claim button */}
            {claimable !== undefined && claimable > 0n && callerAddress && (
              <button
                className="btn-primary w-full py-3 text-sm"
                style={{ background: isClaiming ? undefined : 'linear-gradient(to right, #059669, #10b981)' }}
                disabled={isClaiming}
                onClick={async () => {
                  if (isClaiming) return
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
                }}
              >
                {isClaiming ? 'Claiming...' : 'Claim Funds'}
              </button>
            )}
            {claimError && <p className="text-red-400 text-xs">{claimError}</p>}
          </div>
        </div>
      </div>

      {/* Footer: Initia features */}
      <div className="mt-8 flex items-center justify-center gap-6 text-[10px] uppercase tracking-widest text-gray-600">
        <span>Own Minitia</span>
        <span className="text-gray-800">|</span>
        <span>ICosmos Precompile</span>
        <span className="text-gray-800">|</span>
        <span>Connect Oracle</span>
        <span className="text-gray-800">|</span>
        <span>minievm</span>
        <span className="text-gray-800">|</span>
        <span>Wallet Widget</span>
      </div>
    </div>
  )
}
