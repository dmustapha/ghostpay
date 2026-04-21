export enum StreamStatus {
  ACTIVE = 0,
  COMPLETED = 1,
  CANCELLED = 2,
}

export interface StreamView {
  streamId: string;
  sender: string;
  senderCosmos: string; // DEV-008: needed for cosmos bank refunds
  receiver: string;
  destChannel: string;
  totalAmount: bigint;
  amountSent: bigint;
  ratePerTick: bigint;
  startTime: number;
  endTime: number;
  active: boolean;
}

export interface RegistryStream {
  streamId: string;
  sender: string;
  receiver: string;
  destChannel: string;
  totalAmount: bigint;
  amountSent: bigint;
  ratePerTick: bigint;
  startTime: number;
  endTime: number;
  lastTickTime: number;
  usdValueTotal: bigint;
  status: StreamStatus;
}

export interface IncomingStream {
  streamId: string;
  sender: string;
  totalReceived: bigint;
  lastReceiveTime: number;
}

export interface OraclePrice {
  price: bigint;
  timestamp: number;
  decimal: number;
}

export interface ChainConfig {
  chainId: string;
  name: string;
  rpcUrl: string;
  restUrl: string;
  viemChain: import('viem').Chain;
}

/** Cosmos SDK message for wallet submission */
export interface CosmosMsg {
  typeUrl: string
  value: Record<string, unknown>
}

// DEV-008: createStream takes explicit amount + senderCosmos
export interface CreateStreamParams {
  senderCosmos: string;
  receiver: string;
  destChannel: string;
  totalAmount: string;
  durationSeconds: number;
}
