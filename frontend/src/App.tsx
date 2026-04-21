// DEV-007: All contracts on Settlement — single chain config
// InterwovenKit migration: replaces @initia/react-wallet-widget per hackathon requirement
import { BrowserRouter, Routes, Route, Link } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createConfig, http, WagmiProvider } from 'wagmi'
import { mainnet } from 'wagmi/chains'
import {
  InterwovenKitProvider,
  injectStyles,
  initiaPrivyWalletConnector,
  useInterwovenKit,
  TESTNET,
} from '@initia/interwovenkit-react'
import css from '@initia/interwovenkit-react/styles.css?inline'
import { Layout } from './components/Layout'
import { ErrorBoundary } from './components/ErrorBoundary'
import { Landing } from './pages/Landing'
import { Dashboard } from './pages/Dashboard'
import { CreateStream } from './pages/CreateStream'
import { DemoView } from './pages/DemoView'
import { SETTLEMENT } from './config/chains'
import { useState, useCallback, useRef } from 'react'
import { useAutoSign } from './hooks/useAutoSign'
import type { CosmosMsg } from './types'

// Inject InterwovenKit styles into Shadow DOM
injectStyles(css)

const wagmiConfig = createConfig({
  connectors: [initiaPrivyWalletConnector],
  chains: [mainnet],
  transports: { [mainnet.id]: http() },
})

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 5000,
    },
  },
})

function AppRoutes() {
  const { address: rawAddress, openConnect, requestTxBlock } = useInterwovenKit()
  const address = rawAddress || undefined
  const requestTxBlockRef = useRef(requestTxBlock)
  requestTxBlockRef.current = requestTxBlock
  const [lastTickTime, setLastTickTime] = useState<number | null>(null)

  const submitTxBlock = useCallback(async (params: { msgs: CosmosMsg[] }) => {
    const result = await requestTxBlockRef.current({
      messages: params.msgs as import('@cosmjs/proto-signing').EncodeObject[],
    })
    setLastTickTime(Date.now())
    return result
  }, [])

  const ghostWallet = useAutoSign(address, submitTxBlock)

  const autoSign = {
    enable: async (_chainId: string) => {
      if (!address) { openConnect(); return }
      await ghostWallet.enable()
    },
    enabled: ghostWallet.isActive,
    status: ghostWallet.status,
    disable: ghostWallet.disable,
  }

  const dashboardWallet = address ? {
    address,
    submitTxBlock: async (_chainId: string, msgs: unknown[]) => { await submitTxBlock({ msgs: msgs as CosmosMsg[] }) },
  } : null

  return (
    <Layout ghostWalletActive={ghostWallet.isActive}>
      <Routes>
        <Route path="/" element={<Landing />} />
        <Route
          path="/dashboard"
          element={<Dashboard address={address} wallet={dashboardWallet} />}
        />
        <Route
          path="/create"
          element={
            <CreateStream
              address={address}
              autoSign={autoSign}
              submitTxBlock={submitTxBlock}
            />
          }
        />
        <Route
          path="/demo"
          element={
            <DemoView
              senderAddress={address || import.meta.env.VITE_DEMO_SENDER_ADDRESS}
              receiverAddress={import.meta.env.VITE_DEMO_RECEIVER_ADDRESS}
              lastTickTime={lastTickTime}
              callerAddress={address}
              submitTxBlock={submitTxBlock}
            />
          }
        />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </Layout>
  )
}

function NotFound() {
  return (
    <div className="min-h-[60vh] flex items-center justify-center px-5">
      <div className="text-center">
        <h2 className="text-4xl font-bold mb-3 font-head">404</h2>
        <p className="text-gray-400 mb-6">This page doesn't exist.</p>
        <Link to="/" className="btn-primary px-6 py-2.5 text-sm">Back to Home</Link>
      </div>
    </div>
  )
}

function App() {
  return (
    <ErrorBoundary>
      <WagmiProvider config={wagmiConfig}>
        <QueryClientProvider client={queryClient}>
          <InterwovenKitProvider
            {...TESTNET}
            theme="dark"
            enableAutoSign={{
              [SETTLEMENT.chainId]: ['/minievm.evm.v1.MsgCall'],
            }}
          >
            <BrowserRouter>
              <AppRoutes />
            </BrowserRouter>
          </InterwovenKitProvider>
        </QueryClientProvider>
      </WagmiProvider>
    </ErrorBoundary>
  )
}

export default App
