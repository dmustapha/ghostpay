// DEV-007: All contracts on Settlement
// DEV-008: createStream takes senderCosmos + amount (not msg.value)
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { encodeFunctionData } from 'viem'
import { STREAM_SENDER_ADDRESS, STREAM_SENDER_ABI } from '../config/contracts'
import { SETTLEMENT } from '../config/chains'
import { useOraclePrice, formatUsdValue } from '../hooks/useOracle'

interface CreateStreamProps {
  address: string | undefined
  autoSign: { enable: (chainId: string) => Promise<void>; enabled: boolean }
  submitTxBlock: (params: { msgs: any[] }) => Promise<any>
}

export function CreateStream({ address, autoSign, submitTxBlock }: CreateStreamProps) {
  const navigate = useNavigate()
  const { data: oraclePrice } = useOraclePrice()
  const [senderCosmos, setSenderCosmos] = useState('')
  const [receiver, setReceiver] = useState('')
  const [amount, setAmount] = useState('')
  const [duration, setDuration] = useState('300')
  const [destChannel, setDestChannel] = useState(import.meta.env.VITE_DEST_CHANNEL || 'channel-0')
  const [isCreating, setIsCreating] = useState(false)
  const [autoSignEnabled, setAutoSignEnabled] = useState(false)
  const [txError, setTxError] = useState<string | null>(null)

  const handleEnableAutoSign = async () => {
    try {
      await autoSign.enable(SETTLEMENT.chainId)
      setAutoSignEnabled(true)
    } catch (err) {
      console.error('Auto-sign enable failed:', err)
    }
  }

  const handleCreate = async () => {
    if (!address || !receiver || !amount || !senderCosmos || isCreating) return
    setIsCreating(true)
    setTxError(null)
    try {
      const amountUmin = (() => { try { return BigInt(amount) } catch { throw new Error('Invalid amount \u2014 enter a whole number of umin') } })()
      const calldata = encodeFunctionData({
        abi: STREAM_SENDER_ABI,
        functionName: 'createStream',
        args: [senderCosmos, receiver, destChannel, amountUmin, BigInt(duration)],
      })

      await submitTxBlock({
        msgs: [{
          typeUrl: '/minievm.evm.v1.MsgCall',
          value: {
            sender: address,
            contract_addr: STREAM_SENDER_ADDRESS,
            input: calldata,
            value: '0',
          },
        }],
      })

      navigate('/dashboard')
    } catch (err) {
      console.error('Create stream failed:', err)
      setTxError(err instanceof Error ? err.message : 'Transaction failed. Check console for details.')
    } finally {
      setIsCreating(false)
    }
  }

  const amountBigInt = (() => {
    try { return amount && /^\d+$/.test(amount) ? BigInt(amount) : 0n } catch { return 0n }
  })()
  const tickCount = Math.floor(Number(duration) / 30) || 1
  const ratePerTick = amountBigInt > 0n ? amountBigInt / BigInt(tickCount) : 0n

  return (
    <div className="max-w-[560px] mx-auto px-5 py-6">
      <h2 className="text-2xl font-bold mb-2 font-head">Create Payment Stream</h2>
      <p className="text-sm text-gray-500 mb-6">Set up a continuous payment that flows automatically every 30 seconds.</p>

      <div className="card p-6 space-y-5">
        <Field label="Your Cosmos Address" hint="Used for refunds if stream is cancelled">
          <input
            type="text"
            value={senderCosmos}
            onChange={(e) => setSenderCosmos(e.target.value)}
            placeholder="init1..."
            className="input-field"
          />
        </Field>

        <Field label="Recipient Address" hint="Cosmos bech32 address of the receiver">
          <input
            type="text"
            value={receiver}
            onChange={(e) => setReceiver(e.target.value)}
            placeholder="init1..."
            className="input-field"
          />
        </Field>

        <Field label="Amount" hint="Total payment in umin (1 MIN = 1,000,000 umin)">
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="1000000"
            min="0"
            step="1000"
            className="input-field"
          />
          {oraclePrice && amountBigInt > 0n && (
            <p className="text-xs text-ghost-400 mt-1.5">{formatUsdValue(amountBigInt, oraclePrice)}</p>
          )}
          <p className="text-[11px] text-gray-600 mt-1">Pre-fund the StreamSender contract via cosmos bank send before creating.</p>
        </Field>

        <Field label="Duration">
          <select
            value={duration}
            onChange={(e) => setDuration(e.target.value)}
            className="input-field"
          >
            <option value="120">2 minutes</option>
            <option value="300">5 minutes</option>
            <option value="600">10 minutes</option>
            <option value="1800">30 minutes</option>
            <option value="3600">1 hour</option>
          </select>
        </Field>

        <Field label="Destination Channel">
          <input
            type="text"
            value={destChannel}
            onChange={(e) => setDestChannel(e.target.value)}
            className="input-field"
          />
        </Field>

        {/* Rate preview */}
        {ratePerTick > 0n && (
          <div className="bg-ghost-950/40 border border-ghost-800/30 rounded-xl p-4 space-y-1.5">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Rate per tick</span>
              <span className="text-white font-mono">{(Number(ratePerTick) / 1e6).toFixed(4)} MIN</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Total ticks</span>
              <span className="text-white font-mono">{tickCount}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Tick interval</span>
              <span className="text-white font-mono">30s</span>
            </div>
          </div>
        )}

        {/* Auto-sign */}
        {!autoSignEnabled && (
          <button onClick={handleEnableAutoSign} className="btn-secondary w-full py-3 text-sm">
            Enable Ghost Wallet (Auto-Sign)
          </button>
        )}
        {autoSignEnabled && (
          <div className="flex items-center gap-2.5 px-4 py-2.5 rounded-xl bg-ghost-950/30 border border-ghost-700/20">
            <div className="w-2 h-2 rounded-full bg-ghost-400 animate-pulse" />
            <span className="text-sm text-ghost-300">Ghost Wallet enabled</span>
          </div>
        )}

        {/* Submit */}
        <button
          onClick={handleCreate}
          disabled={isCreating || !receiver || !amount || !senderCosmos || !address}
          className="btn-primary w-full py-3.5 text-sm"
        >
          {isCreating ? 'Creating Stream...' : 'Start Stream'}
        </button>

        {txError && (
          <p className="text-red-400 text-sm">{txError}</p>
        )}
      </div>
    </div>
  )
}

function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="label">{label}</label>
      {hint && <p className="text-[11px] text-gray-600 -mt-1 mb-2">{hint}</p>}
      {children}
    </div>
  )
}
