// Ghost Wallet: Cosmos authz grant for auto-signing stream ticks
// Uses MsgGrant (GenericAuthorization for MsgCall) + MsgGrantAllowance (feegrant)
// Graceful fallback: if grant fails, ticks still work with manual approval

import { useState, useCallback, useEffect } from 'react'
import type { CosmosMsg } from '../types'

type SubmitFn = (params: { msgs: CosmosMsg[] }) => Promise<unknown>
type AutoSignStatus = 'idle' | 'granting' | 'active' | 'error'

const STORAGE_KEY = 'ghostpay_autosign'

function isGrantValid(parsed: { address: string; active: boolean; expiration?: string }, address: string): boolean {
  if (parsed.address !== address || !parsed.active) return false
  if (parsed.expiration) {
    const expiresAt = new Date(parsed.expiration).getTime()
    if (expiresAt <= Date.now()) return false
  }
  return true
}

export function useAutoSign(address: string | undefined, submitTxBlock: SubmitFn) {
  const [status, setStatus] = useState<AutoSignStatus>(() => {
    if (!address) return 'idle'
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      if (stored) {
        const parsed = JSON.parse(stored)
        if (isGrantValid(parsed, address)) return 'active'
        // Expired — clean up
        if (parsed.address === address) localStorage.removeItem(STORAGE_KEY)
      }
    } catch { /* ignore */ }
    return 'idle'
  })

  // Reset when address changes
  useEffect(() => {
    if (!address) {
      setStatus('idle')
      return
    }
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      if (stored) {
        const parsed = JSON.parse(stored)
        if (isGrantValid(parsed, address)) {
          setStatus('active')
          return
        }
        // Expired — clean up
        if (parsed.address === address) localStorage.removeItem(STORAGE_KEY)
      }
    } catch { /* ignore */ }
    setStatus('idle')
  }, [address])

  const enable = useCallback(async () => {
    if (!address) return
    setStatus('granting')

    try {
      // Demo: self-grant (granter == grantee). The on-chain authz grant is recorded
      // but doesn't change signing behavior since the user already controls the address.
      // Production would generate a separate client-side keypair as grantee, enabling
      // true background signing without wallet popups.
      const granteeAddress = address

      const expirationDate = new Date(Date.now() + 24 * 60 * 60 * 1000) // 24h
      const expirationStr = expirationDate.toISOString().replace(/\.\d{3}Z$/, 'Z')

      // MsgGrant: authorize MsgCall execution
      const grantMsg = {
        typeUrl: '/cosmos.authz.v1beta1.MsgGrant',
        value: {
          granter: address,
          grantee: granteeAddress,
          grant: {
            authorization: {
              '@type': '/cosmos.authz.v1beta1.GenericAuthorization',
              msg: '/minievm.evm.v1.MsgCall',
            },
            expiration: expirationStr,
          },
        },
      }

      // MsgGrantAllowance: cover gas fees
      const feegrantMsg = {
        typeUrl: '/cosmos.feegrant.v1beta1.MsgGrantAllowance',
        value: {
          granter: address,
          grantee: granteeAddress,
          allowance: {
            '@type': '/cosmos.feegrant.v1beta1.BasicAllowance',
            spend_limit: [],
            expiration: expirationStr,
          },
        },
      }

      await submitTxBlock({ msgs: [grantMsg, feegrantMsg] })

      setStatus('active')
      localStorage.setItem(STORAGE_KEY, JSON.stringify({
        address,
        active: true,
        grantee: granteeAddress,
        expiration: expirationStr,
      }))
    } catch (err) {
      console.warn('Ghost wallet grant failed — ticks will require manual approval:', err)
      setStatus('error')
      // Auto-recover to idle after 3s so user can retry
      setTimeout(() => setStatus('idle'), 3000)
    }
  }, [address, submitTxBlock])

  const disable = useCallback(async () => {
    if (!address) return

    try {
      const revokeMsg = {
        typeUrl: '/cosmos.authz.v1beta1.MsgRevoke',
        value: {
          granter: address,
          grantee: address,
          msg_type_url: '/minievm.evm.v1.MsgCall',
        },
      }
      await submitTxBlock({ msgs: [revokeMsg] })
    } catch (err) {
      console.warn('Revoke failed:', err)
    }

    setStatus('idle')
    localStorage.removeItem(STORAGE_KEY)
  }, [address, submitTxBlock])

  return {
    status,
    enable,
    disable,
    isActive: status === 'active',
    isGranting: status === 'granting',
  }
}
