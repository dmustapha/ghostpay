// DEV-007: All contracts on Settlement
// DEV-008: createStream signature updated (senderCosmos, amount params)
// DEV-009: StreamSender sends tokens directly to StreamReceiver

const requireAddress = (name: string): string => {
  const addr = import.meta.env[name]
  if (!addr) {
    throw new Error(`Missing required env variable: ${name}. Check your .env file.`)
  }
  return addr
}

export const STREAM_SENDER_ADDRESS = requireAddress('VITE_STREAM_SENDER_ADDRESS')
export const PAYMENT_REGISTRY_ADDRESS = requireAddress('VITE_PAYMENT_REGISTRY_ADDRESS')
export const STREAM_RECEIVER_ADDRESS = requireAddress('VITE_STREAM_RECEIVER_ADDRESS')

export const STREAM_SENDER_ABI = [
  {
    type: 'function',
    name: 'createStream',
    inputs: [
      { name: 'senderCosmos', type: 'string' },
      { name: 'receiver', type: 'string' },
      { name: 'destChannel', type: 'string' },
      { name: 'amount', type: 'uint256' },
      { name: 'durationSeconds', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bytes32' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'sendTick',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'cancelStream',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getStreamInfo',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'streamId', type: 'bytes32' },
          { name: 'sender', type: 'address' },
          { name: 'senderCosmos', type: 'string' },
          { name: 'receiver', type: 'string' },
          { name: 'destChannel', type: 'string' },
          { name: 'totalAmount', type: 'uint256' },
          { name: 'amountSent', type: 'uint256' },
          { name: 'tickCount', type: 'uint256' },
          { name: 'ratePerTick', type: 'uint256' },
          { name: 'startTime', type: 'uint256' },
          { name: 'endTime', type: 'uint256' },
          { name: 'active', type: 'bool' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getSenderStreams',
    inputs: [{ name: 'sender', type: 'address' }],
    outputs: [{ name: '', type: 'bytes32[]' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'StreamCreated',
    inputs: [
      { name: 'streamId', type: 'bytes32', indexed: true },
      { name: 'sender', type: 'address', indexed: true },
      { name: 'receiver', type: 'string', indexed: false },
      { name: 'totalAmount', type: 'uint256', indexed: false },
      { name: 'duration', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'TickSent',
    inputs: [
      { name: 'streamId', type: 'bytes32', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
      { name: 'tickNumber', type: 'uint256', indexed: false },
    ],
  },
] as const

export const STREAM_RECEIVER_ABI = [
  {
    type: 'function',
    name: 'getClaimable',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'claim',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getIncomingStreams',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'bytes32[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getIncomingStream',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'streamId', type: 'bytes32' },
          { name: 'sender', type: 'string' },
          { name: 'totalReceived', type: 'uint256' },
          { name: 'lastReceiveTime', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'PaymentReceived',
    inputs: [
      { name: 'streamId', type: 'bytes32', indexed: true },
      { name: 'receiver', type: 'address', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'FundsClaimed',
    inputs: [
      { name: 'receiver', type: 'address', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
    ],
  },
] as const

export const PAYMENT_REGISTRY_ABI = [
  {
    type: 'function',
    name: 'getStream',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'streamId', type: 'bytes32' },
          { name: 'sender', type: 'string' },
          { name: 'receiver', type: 'string' },
          { name: 'destChannel', type: 'string' },
          { name: 'totalAmount', type: 'uint256' },
          { name: 'amountSent', type: 'uint256' },
          { name: 'ratePerTick', type: 'uint256' },
          { name: 'startTime', type: 'uint256' },
          { name: 'endTime', type: 'uint256' },
          { name: 'lastTickTime', type: 'uint256' },
          { name: 'usdValueTotal', type: 'uint256' },
          { name: 'status', type: 'uint8' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'PaymentProcessed',
    inputs: [
      { name: 'streamId', type: 'bytes32', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
      { name: 'usdValue', type: 'uint256', indexed: false },
      { name: 'tickNumber', type: 'uint256', indexed: false },
    ],
  },
] as const
