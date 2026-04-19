// DEV-007: All contracts on Settlement — single chain config
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WalletWidgetProvider, useWallet, TESTNET } from '@initia/react-wallet-widget'
import { Layout } from './components/Layout'
import { Landing } from './pages/Landing'
import { Dashboard } from './pages/Dashboard'
import { CreateStream } from './pages/CreateStream'
import { DemoView } from './pages/DemoView'
import { SETTLEMENT } from './config/chains'
import { useState, useCallback, useRef } from 'react'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 5000,
    },
  },
})

function AppRoutes() {
  const wallet = useWallet()
  const walletRef = useRef(wallet)
  walletRef.current = wallet
  const address = wallet.address || undefined
  const [lastTickTime, setLastTickTime] = useState<number | null>(null)

  const submitTxBlock = useCallback(async (params: { msgs: any[] }) => {
    const result = await walletRef.current.requestTx({
      messages: params.msgs,
    })
    setLastTickTime(Date.now())
    return result
  }, [])

  const autoSign = {
    enable: async (_chainId: string) => {
      if (!wallet.address) wallet.onboard()
    },
    enabled: !!wallet.address,
  }

  const dashboardWallet = address ? {
    address,
    submitTxBlock: async (_chainId: string, msgs: unknown[]) => { await submitTxBlock({ msgs: msgs as any[] }) },
  } : null

  return (
    <Layout>
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
      </Routes>
    </Layout>
  )
}

function App() {
  return (
    <WalletWidgetProvider {...TESTNET}>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <AppRoutes />
        </BrowserRouter>
      </QueryClientProvider>
    </WalletWidgetProvider>
  )
}

export default App
