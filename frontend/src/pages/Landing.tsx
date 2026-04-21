import { Link } from 'react-router-dom'
import { useEffect, useRef, useState } from 'react'
import { TICK_INTERVAL_MS } from '../config/chains'

export function Landing() {
  return (
    <div>
      <HeroSection />
      <StatsBar />
      <HowItWorks />
      <TechBadges />
      <footer className="border-t border-ghost-800/20 py-8 text-center">
        <p className="text-gray-600 text-sm">GhostPay — Built for the INITIATE Hackathon on Initia</p>
      </footer>
    </div>
  )
}

function HeroSection() {
  const [counter, setCounter] = useState(0)
  // Derive increment from protocol tick interval: simulate ~74.1 MIN per tick spread over 1s updates
  const incrementPerSecond = 74.1 / (TICK_INTERVAL_MS / 1000)

  useEffect(() => {
    const id = setInterval(() => setCounter(v => v + incrementPerSecond), 1000)
    return () => clearInterval(id)
  }, [incrementPerSecond])

  return (
    <section className="max-w-[1000px] mx-auto px-5 pt-20 pb-10">
      <div className="grid grid-cols-1 md:grid-cols-[55fr_45fr] gap-12 items-center">
        {/* Left: Copy */}
        <div className="relative z-10">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-medium bg-ghost-500/10 text-ghost-300 border border-ghost-500/20 mb-5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            Built on Initia
          </div>
          <h1 className="text-4xl md:text-5xl lg:text-[3.5rem] font-bold leading-[1.1] mb-5 font-head">
            Money that{' '}
            <span className="gp-grad-text">flows,</span>
            <br />
            never sits idle
          </h1>
          <p className="text-gray-400 text-lg leading-relaxed max-w-[480px] mb-8">
            Stream payments per-second across Cosmos chains. Your funds arrive continuously — not in lump sums, not on schedules.
          </p>
          <div className="flex gap-3 flex-wrap">
            <Link to="/create" className="btn-primary px-7 py-3.5 text-base">
              Start Streaming →
            </Link>
            <Link to="/demo" className="btn-secondary px-6 py-3.5 text-base">
              View Live Demo
            </Link>
          </div>
        </div>

        {/* Right: Stream visualization */}
        <div className="relative min-h-[340px] hidden md:block">
          {/* Sender card */}
          <div className="card p-4 absolute top-0 left-0 w-[220px] z-10">
            <div className="flex items-center gap-2 mb-2.5">
              <div className="w-7 h-7 rounded-full bg-gradient-to-br from-ghost-500 to-ghost-400 grid place-items-center text-xs font-bold">S</div>
              <div>
                <div className="text-[11px] text-gray-500">Sender</div>
                <div className="font-mono text-xs">init1...x7a3f</div>
              </div>
            </div>
            <div className="font-mono text-sm text-emerald-400">-2.47 MIN/s</div>
          </div>

          {/* Flow line */}
          <div className="absolute top-[70px] left-[109px] w-[3px] h-[200px] bg-gradient-to-b from-ghost-500/30 to-emerald-500/30 rounded-full">
            <FlowParticles />
          </div>

          {/* Receiver card */}
          <div className="card p-4 absolute bottom-0 right-0 w-[220px] z-10 border-emerald-800/25">
            <div className="flex items-center gap-2 mb-2.5">
              <div className="w-7 h-7 rounded-full bg-gradient-to-br from-emerald-500 to-emerald-600 grid place-items-center text-xs font-bold">R</div>
              <div>
                <div className="text-[11px] text-gray-500">Receiver</div>
                <div className="font-mono text-xs">init1...b1c4</div>
              </div>
            </div>
            <div className="font-mono text-lg text-emerald-400">+{counter.toFixed(2)} MIN</div>
          </div>
        </div>
      </div>
    </section>
  )
}

function FlowParticles() {
  return (
    <>
      {[0, 1, 2, 3].map(i => (
        <span
          key={i}
          className="absolute w-[5px] h-[5px] rounded-full bg-emerald-400 opacity-0 animate-flow-down"
          style={{
            left: '-1px',
            animationDelay: `${i * 0.5}s`,
          }}
        />
      ))}
    </>
  )
}

function StatsBar() {
  return (
    <section className="max-w-[800px] mx-auto px-5 pb-16">
      <div className="text-center mb-3">
        <span className="text-xs text-gray-400 uppercase tracking-wider">Demo Preview</span>
      </div>
      <div className="grid grid-cols-3 gap-2 sm:gap-3">
        <StatCard value={14328} label="MIN streamed" />
        <StatCard value={52} label="ticks sent" />
        <StatCard value={3} label="active streams" />
      </div>
    </section>
  )
}

function StatCard({ value, label }: { value: number; label: string }) {
  const ref = useRef<HTMLDivElement>(null)
  const [displayed, setDisplayed] = useState(0)
  const [started, setStarted] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver(([e]) => {
      if (e.isIntersecting && !started) {
        setStarted(true)
        io.disconnect()
      }
    }, { threshold: 0.3 })
    io.observe(el)
    return () => io.disconnect()
  }, [started])

  useEffect(() => {
    if (!started) return
    const duration = 1200
    const start = performance.now()
    function tick(now: number) {
      const progress = Math.min((now - start) / duration, 1)
      const eased = 1 - Math.pow(1 - progress, 3)
      setDisplayed(Math.floor(value * eased))
      if (progress < 1) requestAnimationFrame(tick)
    }
    requestAnimationFrame(tick)
  }, [started, value])

  return (
    <div ref={ref} className="card text-center py-5 px-3">
      <div className="font-mono text-2xl font-bold gp-grad-text">{displayed.toLocaleString()}</div>
      <div className="text-xs text-gray-500 mt-1">{label}</div>
    </div>
  )
}

function HowItWorks() {
  const steps = [
    { num: '1', title: 'Create', desc: 'Set recipient, amount, and duration. Your stream is configured on your own Minitia appchain.', color: 'ghost' },
    { num: '2', title: 'Stream', desc: 'Ghost wallet ticks funds per-second through IBC. No manual sending — it flows automatically.', color: 'ghost' },
    { num: '3', title: 'Claim', desc: 'Recipients claim accrued balance anytime. Funds land instantly on the destination chain.', color: 'emerald' },
  ]

  return (
    <section className="max-w-[900px] mx-auto px-5 pb-20">
      <h2 className="text-2xl font-bold mb-10 font-head">
        How it <span className="gp-grad-text">works</span>
      </h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-0 relative">
        {/* Connecting line */}
        <div className="hidden md:block absolute top-6 left-6 right-6 h-[2px] bg-gradient-to-r from-ghost-500/30 to-emerald-500/30 rounded-full" />

        {steps.map((s, i) => (
          <div key={i} className="flex md:flex-col gap-5 items-start py-5 relative z-10">
            <div className={`w-12 h-12 rounded-xl grid place-items-center flex-shrink-0 border font-bold font-head ${
              s.color === 'emerald'
                ? 'bg-emerald-500/10 border-emerald-500/25 text-emerald-400'
                : 'bg-ghost-500/10 border-ghost-500/25 text-ghost-300'
            }`}>
              {s.num}
            </div>
            <div>
              <h3 className="text-base font-semibold mb-1 font-head">{s.title}</h3>
              <p className="text-sm text-gray-500 leading-relaxed">{s.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}

function TechBadges() {
  const badges = [
    { label: 'Own Minitia', accent: false },
    { label: 'ICosmos', accent: false },
    { label: 'Connect Oracle', accent: true },
    { label: 'minievm', accent: false },
    { label: 'Wallet Widget', accent: true },
  ]

  return (
    <section className="max-w-[800px] mx-auto px-5 pb-16">
      <div className="flex flex-wrap gap-2.5 justify-center">
        {badges.map(b => (
          <span
            key={b.label}
            className={`text-xs font-medium px-3 py-1.5 rounded-full border ${
              b.accent
                ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                : 'bg-ghost-500/10 text-ghost-300 border-ghost-500/20'
            }`}
          >
            {b.label}
          </span>
        ))}
      </div>
    </section>
  )
}
