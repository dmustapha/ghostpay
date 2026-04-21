export const FEATURES = {
  IBC_MODE: import.meta.env.VITE_IBC_MODE === 'true',
  GHOST_WALLET: import.meta.env.VITE_GHOST_WALLET !== 'false', // default ON
} as const
