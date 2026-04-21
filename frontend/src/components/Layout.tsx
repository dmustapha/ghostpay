import { Link, useLocation } from 'react-router-dom'
import { useState } from 'react'

export function Layout({ children, ghostWalletActive }: { children: React.ReactNode; ghostWalletActive?: boolean }) {
  const { pathname } = useLocation()
  const [menuOpen, setMenuOpen] = useState(false)

  return (
    <div className="min-h-[100dvh]">
      <nav className="border-b border-gray-800/60 backdrop-blur-md bg-gray-950/80 sticky top-0 z-50">
        <div className="max-w-[1000px] mx-auto px-5 py-3 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2.5 group">
            <img src="/logo.svg" alt="GhostPay" className="w-8 h-8 drop-shadow-lg group-hover:drop-shadow-[0_0_8px_rgba(76,110,245,0.4)] transition-all duration-200" />
            <span className="text-lg font-bold tracking-tight font-head">GhostPay</span>
          </Link>

          {/* Desktop nav */}
          <div className="hidden md:flex items-center gap-1 bg-gray-900/60 rounded-xl p-1 border border-gray-800/40">
            <NavLink to="/" active={pathname === '/'}>Home</NavLink>
            <NavLink to="/dashboard" active={pathname === '/dashboard'}>Dashboard</NavLink>
            <NavLink to="/create" active={pathname === '/create'}>New Stream</NavLink>
            <NavLink to="/demo" active={pathname === '/demo'}>Live Demo</NavLink>
          </div>

          {ghostWalletActive && (
            <div className="hidden md:flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-ghost-950/40 border border-ghost-700/20">
              <div className="w-1.5 h-1.5 rounded-full bg-ghost-400 animate-pulse" />
              <span className="text-[10px] text-ghost-400 uppercase tracking-wider">Ghost</span>
            </div>
          )}

          {/* Mobile hamburger */}
          <button
            className="md:hidden p-2 text-gray-400 hover:text-white"
            onClick={() => setMenuOpen(!menuOpen)}
            aria-label="Toggle menu"
          >
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2">
              {menuOpen ? (
                <path d="M4 4l12 12M16 4L4 16" />
              ) : (
                <path d="M3 5h14M3 10h14M3 15h14" />
              )}
            </svg>
          </button>
        </div>

        {/* Mobile menu */}
        {menuOpen && (
          <div className="md:hidden border-t border-gray-800/40 px-5 py-3 flex flex-col gap-1 bg-gray-950/95">
            <MobileNavLink to="/" active={pathname === '/'} onClick={() => setMenuOpen(false)}>Home</MobileNavLink>
            <MobileNavLink to="/dashboard" active={pathname === '/dashboard'} onClick={() => setMenuOpen(false)}>Dashboard</MobileNavLink>
            <MobileNavLink to="/create" active={pathname === '/create'} onClick={() => setMenuOpen(false)}>New Stream</MobileNavLink>
            <MobileNavLink to="/demo" active={pathname === '/demo'} onClick={() => setMenuOpen(false)}>Live Demo</MobileNavLink>
          </div>
        )}
      </nav>
      <main>{children}</main>
    </div>
  )
}

function NavLink({ to, active, children }: { to: string; active: boolean; children: React.ReactNode }) {
  return (
    <Link
      to={to}
      className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors duration-200 ${
        active
          ? 'bg-ghost-600/25 text-ghost-300'
          : 'text-gray-500 hover:text-white'
      }`}
    >
      {children}
    </Link>
  )
}

function MobileNavLink({ to, active, onClick, children }: { to: string; active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <Link
      to={to}
      onClick={onClick}
      className={`px-3 py-2.5 rounded-lg text-sm font-medium transition-colors duration-200 ${
        active
          ? 'bg-ghost-600/25 text-ghost-300'
          : 'text-gray-400 hover:text-white hover:bg-gray-800/40'
      }`}
    >
      {children}
    </Link>
  )
}
