// Bigint-safe formatting — avoids Number(bigint) precision loss for amounts > 2^53

const MICRO_DIVISOR = 1_000_000n

/** Format micro-denom bigint to human-readable decimal string (e.g. 1234567n → "1.2345") */
export function formatAmount(microAmount: bigint, decimals = 4): string {
  const whole = microAmount / MICRO_DIVISOR
  const frac = microAmount % MICRO_DIVISOR
  const fracStr = frac.toString().padStart(6, '0').slice(0, decimals)
  return `${whole.toString()}.${fracStr}`
}

/** Format micro-denom bigint with full 6-decimal precision */
export function formatAmountFull(microAmount: bigint): string {
  return formatAmount(microAmount, 6)
}
