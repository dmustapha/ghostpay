// DEV-007: All contracts on Settlement
import { Link } from 'react-router-dom'
import { useSentStreams, useClaimableBalance } from '../hooks/useStreams'
import { useOraclePrice } from '../hooks/useOracle'
import { useStreamTick } from '../hooks/useStreamTick'
import { useClaim } from '../hooks/useClaim'
import { StreamCard } from '../components/StreamCard'
import { SETTLEMENT } from '../config/chains'
import type { CosmosMsg } from '../types'
import { formatAmount } from '../utils/format'

interface DashboardProps {
  address: string | undefined
  wallet: { address: string; submitTxBlock: (chainId: string, msgs: unknown[]) => Promise<void> } | null
}

import { useCallback, useRef } from 'react'

export function Dashboard({ address, wallet }: DashboardProps) {
  const { data: sentStreams, isLoading: loadingSent } = useSentStreams(address)
  const { data: claimable } = useClaimableBalance(address)
  const { data: oraclePrice } = useOraclePrice()

  const walletRef = useRef(wallet)
  walletRef.current = wallet

  const stableSubmitTx = useCallback(async (params: { msgs: CosmosMsg[] }) => {
    if (!walletRef.current) return
    await walletRef.current.submitTxBlock(SETTLEMENT.chainId, params.msgs)
  }, [])

  const { claim, isClaiming, claimError } = useClaim({
    callerAddress: address,
    submitTxBlock: stableSubmitTx,
  })

  const activeStream = sentStreams?.find((s) => s.active)
  const { tickCount, isSending: isAutoTicking } = useStreamTick({
    streamId: activeStream?.streamId ?? '',
    enabled: !!activeStream && !!wallet,
    senderAddress: wallet?.address ?? '',
    submitTxBlock: stableSubmitTx,
  })

  if (!address) {
    return (
      <div className="text-center py-24">
        <div className="w-16 h-16 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-ghost-500 to-ghost-700 flex items-center justify-center text-2xl shadow-xl shadow-ghost-900/40">
          G
        </div>
        <h2 className="text-2xl font-bold mb-3 font-head">Welcome to GhostPay</h2>
        <p className="text-gray-400 max-w-md mx-auto mb-8">
          Connect your Initia wallet to start streaming continuous payments across rollups.
        </p>
        <Link to="/demo" className="btn-secondary px-6 py-3 inline-block">
          View Live Demo
        </Link>
      </div>
    )
  }

  return (
    <div className="max-w-[960px] mx-auto px-5 py-6 space-y-8">
      {/* Claimable balance banner */}
      {claimable !== undefined && claimable > 0n && (
        <div className="card p-6 glow-green border-emerald-800/40">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs font-medium text-emerald-400 uppercase tracking-wider mb-1">Claimable Balance</p>
              <p className="text-3xl font-bold font-mono tabular-nums text-white">
                {formatAmount(claimable)}
                <span className="text-lg text-gray-400 ml-2">MIN</span>
              </p>
            </div>
            <div className="flex flex-col items-end gap-2">
              <button
                className="btn-primary px-5 py-2.5 text-sm"
                style={{ background: isClaiming ? undefined : 'linear-gradient(to right, #059669, #10b981)' }}
                disabled={isClaiming}
                onClick={claim}
              >
                {isClaiming ? 'Claiming...' : 'Claim Funds'}
              </button>
              {claimError && <p className="text-red-400 text-xs">{claimError}</p>}
            </div>
          </div>
        </div>
      )}

      {/* Ghost wallet status */}
      {activeStream && (
        <div className="card px-5 py-3.5 flex items-center justify-between border-ghost-600/20">
          <div className="flex items-center gap-3">
            <div className={`w-2 h-2 rounded-full ${isAutoTicking ? 'bg-ghost-400 animate-pulse' : 'bg-ghost-500'}`} />
            <span className="text-sm text-ghost-300">
              {isAutoTicking ? 'Sending tick...' : `Ghost Wallet active \u2014 ${tickCount} ticks sent`}
            </span>
          </div>
          <span className="text-gray-600 text-xs font-mono">{activeStream.streamId.slice(0, 12)}...</span>
        </div>
      )}

      {/* Sent streams */}
      <section>
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-lg font-semibold font-head">Your Streams</h2>
          <Link to="/create" className="btn-primary px-4 py-2 text-sm">
            New Stream
          </Link>
        </div>

        {loadingSent ? (
          <div className="card p-8 text-center text-gray-500">Loading streams...</div>
        ) : sentStreams && sentStreams.length > 0 ? (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {sentStreams.map((stream) => (
              <StreamCard
                key={stream.streamId}
                stream={stream}
                type="sent"
                oraclePrice={oraclePrice}
              />
            ))}
          </div>
        ) : (
          <div className="card p-10 text-center">
            <p className="text-gray-500 mb-3">No streams yet</p>
            <Link to="/create" className="text-ghost-400 text-sm hover:text-ghost-300 transition-colors">
              Create your first payment stream
            </Link>
          </div>
        )}
      </section>
    </div>
  )
}
