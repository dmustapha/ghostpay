import { Link, useLocation } from 'react-router-dom'

export function Layout({ children }: { children: React.ReactNode }) {
  const { pathname } = useLocation()

  return (
    <div className="min-h-screen">
      <nav className="border-b border-gray-800/60 backdrop-blur-md bg-gray-950/80 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-6 py-3.5 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-3 group">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-ghost-500 to-ghost-700 flex items-center justify-center text-lg shadow-lg shadow-ghost-900/30 group-hover:shadow-ghost-600/30 transition-shadow">
              G
            </div>
            <span className="text-lg font-bold tracking-tight">GhostPay</span>
          </Link>
          <div className="flex items-center gap-1.5">
            <NavLink to="/" active={pathname === '/'}>Dashboard</NavLink>
            <NavLink to="/create" active={pathname === '/create'}>New Stream</NavLink>
            <NavLink to="/demo" active={pathname === '/demo'}>Live Demo</NavLink>
          </div>
        </div>
      </nav>
      <main className="max-w-7xl mx-auto px-6 py-8">{children}</main>
    </div>
  )
}

function NavLink({ to, active, children }: { to: string; active: boolean; children: React.ReactNode }) {
  return (
    <Link
      to={to}
      className={`px-3.5 py-2 rounded-xl text-sm font-medium transition-all duration-200 ${
        active
          ? 'bg-ghost-600/20 text-ghost-300 border border-ghost-600/30'
          : 'text-gray-400 hover:text-white hover:bg-gray-800/60'
      }`}
    >
      {children}
    </Link>
  )
}
