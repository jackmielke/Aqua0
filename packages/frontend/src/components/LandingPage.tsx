import { Globe, Layers, Zap } from "lucide-react"
import WorldIDAuth from "./WorldIDAuth"

interface LandingPageProps {
  onSuccess: () => void
}

export default function LandingPage({ onSuccess }: LandingPageProps) {
  return (
    <div className="min-h-screen bg-black text-white font-sans space-bg">
      <div className="max-w-5xl mx-auto p-6 md:p-12 animate-in fade-in slide-in-from-bottom-4 duration-500">
        {/* Hero Section */}
        <section className="mb-16 md:mb-24 pt-8 md:pt-16 text-center md:text-left">
          <div className="flex items-center justify-center md:justify-start gap-3 mb-8">
            <div className="w-16 h-16 border-4 border-white bg-black flex items-center justify-center rounded-lg">
              <img
                src="/aqua0-logo.png"
                alt="Aqua0 Logo"
                className="w-12 h-12 object-contain invert"
              />
            </div>
            <h1 className="text-5xl font-bold tracking-tighter text-white uppercase">AQUA0</h1>
          </div>

          <div className="inline-block mb-6 px-3 py-1 border border-white text-xs font-mono uppercase tracking-widest animate-pulse">
            Cross-Chain Liquidity Protocol
          </div>

          <h2 className="text-5xl md:text-8xl font-bold leading-[0.9] tracking-tighter mb-8 uppercase">
            Liquidity <br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-white to-gray-500">Unbound</span>
          </h2>

          <p className="text-lg md:text-xl text-gray-300 max-w-2xl leading-relaxed font-light mb-10">
            Solve the capital fragmentation problem. Allocate the same capital to multiple trading strategies across
            different blockchains simultaneously.
          </p>

          {/* World ID Auth Card */}
          <div className="neo-card p-8 inline-block mb-12">
            <div className="mb-6 text-center">
              <h3 className="text-2xl font-bold text-white uppercase tracking-tight mb-2">Get Started</h3>
              <p className="text-sm text-gray-400">Verify your humanity to access the protocol</p>
            </div>

            <WorldIDAuth
              onSuccess={() => {
                console.log('✅ Authentication successful!')
                onSuccess()
              }}
              onError={(error) => {
                console.error('❌ Authentication failed:', error)
              }}
            />
          </div>
        </section>

        {/* Features Grid */}
        <section className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-20">
          <div className="neo-card p-8 relative group">
            <div className="absolute top-4 right-4">
              <Globe className="w-8 h-8" strokeWidth={1.5} />
            </div>
            <h3 className="text-2xl font-bold mb-4 mt-4 uppercase">Cross-Chain</h3>
            <p className="text-gray-400 leading-relaxed">
              Capital stays in your wallet. Tokens move via LayerZero only when needed for execution.
            </p>
          </div>

          <div className="neo-card p-8 relative group">
            <div className="absolute top-4 right-4">
              <Layers className="w-8 h-8" strokeWidth={1.5} />
            </div>
            <h3 className="text-2xl font-bold mb-4 mt-4 uppercase">SLAC Model</h3>
            <p className="text-gray-400 leading-relaxed">
              Shared Liquidity Amplification Coefficient. Achieve 3-10x capital efficiency.
            </p>
          </div>

          <div className="neo-card p-8 relative group">
            <div className="absolute top-4 right-4">
              <Zap className="w-8 h-8" strokeWidth={1.5} />
            </div>
            <h3 className="text-2xl font-bold mb-4 mt-4 uppercase">Auto-Compound</h3>
            <p className="text-gray-400 leading-relaxed">
              Profits and fees are automatically pushed back to your wallet and compounded.
            </p>
          </div>
        </section>

        {/* How it Works */}
        <section className="border-t-2 border-white pt-16">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
            <div>
              <h2 className="text-4xl font-bold mb-8 uppercase tracking-tight">How It Works</h2>
              <div className="space-y-8">
                <div className="flex gap-6">
                  <div className="text-4xl font-bold opacity-30">01</div>
                  <div>
                    <h4 className="text-xl font-bold mb-2 uppercase">Define Strategy</h4>
                    <p className="text-gray-400">
                      Create liquidity strategies for Uniswap on Base using your WorldChain capital.
                    </p>
                  </div>
                </div>
                <div className="flex gap-6">
                  <div className="text-4xl font-bold opacity-30">02</div>
                  <div>
                    <h4 className="text-xl font-bold mb-2 uppercase">Ship Capital</h4>
                    <p className="text-gray-400">
                      Virtual accounting updates your position. No initial token movement required.
                    </p>
                  </div>
                </div>
                <div className="flex gap-6">
                  <div className="text-4xl font-bold opacity-30">03</div>
                  <div>
                    <h4 className="text-xl font-bold mb-2 uppercase">Earn Yield</h4>
                    <p className="text-gray-400">
                      Trades execute against your strategies. Fees accrue in real-time.
                    </p>
                  </div>
                </div>
              </div>
            </div>
            <div className="neo-card aspect-square flex items-center justify-center p-12 relative overflow-hidden">
              <div className="absolute inset-0 opacity-20 bg-[radial-gradient(circle_at_center,_var(--tw-gradient-stops))] from-white via-transparent to-transparent"></div>
              <img
                src="/aqua0-logo.png"
                alt="Aqua0 Diagram"
                width={200}
                height={200}
                className="w-32 h-32 md:w-48 md:h-48 object-contain invert animate-pulse"
              />
            </div>
          </div>
        </section>
      </div>
    </div>
  )
}
