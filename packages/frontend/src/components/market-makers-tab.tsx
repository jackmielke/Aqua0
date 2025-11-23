"use client"
import { useState } from "react"
import { Plus, TrendingUp, ArrowRight, Droplet, Wallet, Layers, X, Waves, Target, ArrowLeftRight, ChevronLeft, ExternalLink, CheckCircle } from "lucide-react"
import { StrategyDetail } from "./strategy-detail"
import { DotLoader } from "./ui/dot-loader"
import { shipStrategyToChain, TOKENS } from "@/lib/shipStrategy"

interface Strategy {
  id: string
  name: string
  chainFrom: string
  chainTo: string
  liquidity: string
  status: "active" | "idle"
}

const mockStrategies: Strategy[] = [
  {
    id: "1",
    name: "ETH/USDC V3",
    chainFrom: "WorldChain",
    chainTo: "Base",
    liquidity: "$50,000",
    status: "active",
  },
  {
    id: "2",
    name: "Stable Pool",
    chainFrom: "Base",
    chainTo: "WorldChain",
    liquidity: "$28,500",
    status: "active",
  },
]

type StrategyType = "stableswap" | "concentrated" | null

export function MarketMakersTab() {
  const [selectedStrategyId, setSelectedStrategyId] = useState<string | null>(null)
  const [isCreating, setIsCreating] = useState(false)
  const [selectedType, setSelectedType] = useState<StrategyType>(null)
  const [fee, setFee] = useState<string>("")
  const [feeError, setFeeError] = useState<string>("")
  const [tokenFrom, setTokenFrom] = useState<string>("USDC")
  const [tokenTo, setTokenTo] = useState<string>("USDT")
  const [isProcessing, setIsProcessing] = useState(false)
  const [txHash, setTxHash] = useState<string | null>(null)

  // If a strategy is selected, show the detail view
  if (selectedStrategyId) {
    return (
      <StrategyDetail
        strategyId={selectedStrategyId}
        onBack={() => setSelectedStrategyId(null)}
      />
    )
  }

  // If creating a strategy and type is selected, show the form
  if (isCreating && selectedType) {
    const handleFeeChange = (value: string) => {
      setFee(value)
      const numValue = parseFloat(value)
      if (isNaN(numValue)) {
        setFeeError("")
      } else if (numValue < 0 || numValue > 1.5) {
        setFeeError("Fee must be between 0% and 1.5%")
      } else {
        setFeeError("")
      }
    }

    const handleSwapTokens = () => {
      const temp = tokenFrom
      setTokenFrom(tokenTo)
      setTokenTo(temp)
    }

    const handleSubmit = async () => {
      const numValue = parseFloat(fee)
      if (isNaN(numValue) || numValue < 0 || numValue > 1.5) {
        setFeeError("Please enter a valid fee between 0% and 1.5%")
        return
      }

      try {
        // Start processing
        setIsProcessing(true)

        // Convert fee percentage to basis points (e.g., 0.30% = 30 bps)
        const feeBps = Math.round(numValue * 100)

        // Get token addresses
        const token0Address = TOKENS[tokenFrom as keyof typeof TOKENS] || TOKENS.USDC
        const token1Address = TOKENS[tokenTo as keyof typeof TOKENS] || TOKENS.USDT

        console.log('🎯 Starting strategy creation with params:', {
          feeBps,
          token0: tokenFrom,
          token0Address,
          token1: tokenTo,
          token1Address,
        })

        // Call the actual shipStrategyToChain function
        console.log('⏳ Calling shipStrategyToChain...')
        const result = await shipStrategyToChain({
          strategyType: selectedType, // 'stableswap' or 'concentrated'
          feeBps,
          token0: token0Address,
          token1: token1Address,
        })

        console.log('✅ Got result from shipStrategyToChain:', result)

        if (result.success && result.txHash) {
          console.log('🎉 Setting transaction hash:', result.txHash)
          setTxHash(result.txHash)
        } else {
          console.error('❌ Result does not have success/txHash:', result)
          throw new Error('Transaction failed')
        }
      } catch (error) {
        console.error('❌ Error creating strategy:', error)
        console.error('Error type:', typeof error)
        console.error('Error constructor:', error?.constructor?.name)
        console.error('Error message:', error instanceof Error ? error.message : JSON.stringify(error))
        console.error('Error stack:', error instanceof Error ? error.stack : 'No stack trace')
        setFeeError(error instanceof Error ? error.message : 'Failed to create strategy. Check console for details.')
      } finally {
        console.log('🏁 Finished - setting isProcessing to false')
        setIsProcessing(false)
      }
    }

    const handleBackToList = () => {
      // Reset all states
      setIsCreating(false)
      setSelectedType(null)
      setFee("")
      setFeeError("")
      setTokenFrom("USDC")
      setTokenTo("USDT")
      setIsProcessing(false)
      setTxHash(null)
    }

    // If transaction is successful, show success screen
    if (txHash) {
      const explorerUrl = `https://layerzeroscan.com/tx/${txHash}`

      return (
        <div className="p-4 md:p-12 space-y-8 animate-in fade-in zoom-in duration-700">
          <div className="max-w-2xl mx-auto text-center space-y-8">
            {/* Success Icon */}
            <div className="flex justify-center">
              <div className="w-24 h-24 border-4 border-green-500 rounded-full flex items-center justify-center bg-green-500/10 animate-pulse">
                <CheckCircle className="w-12 h-12 text-green-500" strokeWidth={2} />
              </div>
            </div>

            {/* Success Message */}
            <div>
              <h2 className="text-4xl md:text-5xl font-bold text-white tracking-tighter uppercase mb-4">
                Strategy Created!
              </h2>
              <p className="text-gray-400 font-mono text-sm">
                Your {selectedType === "stableswap" ? "Stableswap" : "Concentrated Liquidity"} strategy has been deployed cross-chain
              </p>
            </div>

            {/* Transaction Details */}
            <div className="neo-card p-8 space-y-6">
              <div className="space-y-2">
                <div className="text-xs font-mono uppercase text-gray-500">Transaction Hash</div>
                <div className="text-sm font-mono text-white break-all bg-black/50 p-3 border border-white/10">
                  {txHash}
                </div>
              </div>

              <a
                href={explorerUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 text-white hover:text-gray-300 transition-colors group"
              >
                <span className="font-mono text-sm uppercase tracking-wider">View on LayerZero Scan</span>
                <ExternalLink className="w-4 h-4 group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" strokeWidth={2} />
              </a>
            </div>

            {/* Back to Strategies Button */}
            <button
              onClick={handleBackToList}
              className="bg-white text-black px-8 py-4 font-bold uppercase tracking-wider border-2 border-white hover:bg-black hover:text-white transition-colors shadow-[4px_4px_0px_0px_#ffffff] hover:shadow-[2px_2px_0px_0px_#ffffff] hover:translate-x-[2px] hover:translate-y-[2px]"
            >
              Back to Strategies
            </button>
          </div>
        </div>
      )
    }

    // If processing, show loading screen
    if (isProcessing) {
      return (
        <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-black space-bg">
          <div className="relative z-10 flex flex-col items-center gap-8 animate-in fade-in zoom-in duration-700">
            <h2 className="text-3xl md:text-4xl font-bold tracking-tighter text-white font-space uppercase text-center">
              Creating Strategy...
            </h2>
            <div className="w-12 h-12 border-4 border-white border-t-transparent rounded-full animate-spin" />
            <p className="text-gray-400 font-mono text-sm text-center max-w-md">
              Deploying your cross-chain liquidity strategy.<br />
              This may take a few moments...
            </p>
          </div>
        </div>
      )
    }

    return (
      <div className="p-4 md:p-12 space-y-8 animate-in fade-in slide-in-from-right-4 duration-500">
        {/* Header */}
        <div className="space-y-4">
          <button
            onClick={() => setSelectedType(null)}
            className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors group"
          >
            <ChevronLeft className="w-5 h-5 group-hover:-translate-x-1 transition-transform" strokeWidth={2} />
            <span className="font-mono text-sm uppercase tracking-wider">Back to Type Selection</span>
          </button>

          <div>
            <h2 className="text-4xl md:text-5xl font-bold text-white tracking-tighter uppercase mb-2">
              Create {selectedType === "stableswap" ? "Stableswap" : "Concentrated Liquidity"} Strategy
            </h2>
            <p className="text-gray-400 font-mono text-sm">Configure your cross-chain strategy</p>
          </div>
        </div>

        {/* Form */}
        <div className="neo-card p-8 space-y-8">
          {/* Fee Field */}
          <div className="space-y-3">
            <label className="block text-sm font-bold uppercase tracking-wider text-white">
              Fee (%)
            </label>
            <input
              type="number"
              min="0"
              max="1.5"
              step="0.01"
              value={fee}
              onChange={(e) => handleFeeChange(e.target.value)}
              placeholder="0.30"
              className="w-full bg-black border-2 border-white/30 px-4 py-3 text-white font-mono text-lg focus:border-white focus:outline-none transition-colors"
            />
            {feeError && (
              <p className="text-red-400 text-sm font-mono">{feeError}</p>
            )}
            <p className="text-gray-500 text-xs font-mono">Valid range: 0% - 1.5%</p>
          </div>

          {/* Token Pair */}
          <div className="space-y-3">
            <label className="block text-sm font-bold uppercase tracking-wider text-white">
              Token Pair
            </label>
            <div className="flex items-center gap-4">
              <div className="flex-1">
                <div className="text-xs font-mono uppercase text-gray-500 mb-2">From</div>
                <div className="neo-card px-6 py-4 text-center">
                  <div className="text-2xl font-bold text-white">{tokenFrom}</div>
                </div>
              </div>

              <button
                onClick={handleSwapTokens}
                className="mt-6 p-3 border-2 border-white/30 hover:border-white hover:bg-white/5 transition-all group"
                title="Swap tokens"
              >
                <ArrowLeftRight className="w-6 h-6 group-hover:rotate-180 transition-transform duration-300" strokeWidth={2} />
              </button>

              <div className="flex-1">
                <div className="text-xs font-mono uppercase text-gray-500 mb-2">To</div>
                <div className="neo-card px-6 py-4 text-center">
                  <div className="text-2xl font-bold text-white">{tokenTo}</div>
                </div>
              </div>
            </div>
          </div>

          {/* Submit Button */}
          <button
            onClick={handleSubmit}
            disabled={isProcessing}
            className="w-full bg-white text-black px-6 py-4 font-bold uppercase tracking-wider border-2 border-white hover:bg-black hover:text-white transition-colors shadow-[4px_4px_0px_0px_#ffffff] hover:shadow-[2px_2px_0px_0px_#ffffff] hover:translate-x-[2px] hover:translate-y-[2px] disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isProcessing ? "Processing..." : "Create Strategy"}
          </button>
        </div>
      </div>
    )
  }

  // If creating but no type selected yet, show type selector
  if (isCreating) {
    return (
      <div className="p-4 md:p-12 space-y-8 animate-in fade-in slide-in-from-top-4 duration-500">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h2 className="text-4xl md:text-5xl font-bold text-white tracking-tighter uppercase mb-2">
              Choose Strategy Type
            </h2>
            <p className="text-gray-400 font-mono text-sm">Select the type of liquidity strategy you want to create</p>
          </div>
          <button
            onClick={() => setIsCreating(false)}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" strokeWidth={2} />
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          {/* Stableswap Card */}
          <div
            onClick={() => setSelectedType("stableswap")}
            className="neo-card p-12 hover:bg-white/5 cursor-pointer group relative overflow-hidden transition-all duration-300"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-blue-500/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
            <div className="relative z-10 flex flex-col items-center text-center space-y-6">
              <div className="w-20 h-20 border-2 border-white/30 rounded-full flex items-center justify-center group-hover:border-white transition-colors">
                <Waves className="w-10 h-10" strokeWidth={1.5} />
              </div>
              <div>
                <h3 className="text-3xl font-bold text-white uppercase mb-3 group-hover:underline decoration-2 underline-offset-4">
                  Stableswap
                </h3>
                <p className="text-gray-400 leading-relaxed">
                  Optimized for stable pairs (USDC/USDT). Low slippage, minimal impermanent loss.
                </p>
              </div>
              <div className="pt-4 border-t border-white/10 w-full">
                <div className="text-xs font-mono uppercase text-gray-500">Best for</div>
                <div className="text-sm font-bold text-white mt-1">Stable assets with low volatility</div>
              </div>
            </div>
          </div>

          {/* Concentrated Liquidity Card */}
          <div
            onClick={() => setSelectedType("concentrated")}
            className="neo-card p-12 hover:bg-white/5 cursor-pointer group relative overflow-hidden transition-all duration-300"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-green-500/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
            <div className="relative z-10 flex flex-col items-center text-center space-y-6">
              <div className="w-20 h-20 border-2 border-white/30 rounded-full flex items-center justify-center group-hover:border-white transition-colors">
                <Target className="w-10 h-10" strokeWidth={1.5} />
              </div>
              <div>
                <h3 className="text-3xl font-bold text-white uppercase mb-3 group-hover:underline decoration-2 underline-offset-4">
                  Concentrated Liquidity
                </h3>
                <p className="text-gray-400 leading-relaxed">
                  Focus liquidity in specific price ranges. Higher capital efficiency for volatile pairs.
                </p>
              </div>
              <div className="pt-4 border-t border-white/10 w-full">
                <div className="text-xs font-mono uppercase text-gray-500">Best for</div>
                <div className="text-sm font-bold text-white mt-1">ETH, BTC and volatile assets</div>
              </div>
            </div>
          </div>
        </div>

        <button
          onClick={() => setIsCreating(false)}
          className="text-gray-400 hover:text-white font-mono text-sm uppercase tracking-wider"
        >
          ← Cancel
        </button>
      </div>
    )
  }

  // Otherwise show the list view
  return (
    <div className="p-4 md:p-12 space-y-8">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <h2 className="text-4xl md:text-5xl font-bold text-white tracking-tighter uppercase mb-2">Strategies</h2>
          <p className="text-gray-400 font-mono text-sm">Manage your cross-chain liquidity positions</p>
        </div>
        <button
          onClick={() => setIsCreating(true)}
          className="bg-white text-black px-6 py-3 font-bold uppercase tracking-wider border-2 border-white hover:bg-black hover:text-white transition-colors flex items-center gap-2 shadow-[4px_4px_0px_0px_#ffffff]"
        >
          <Plus className="w-5 h-5" strokeWidth={2} />
          <span>Create Strategy</span>
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-12">
        <div className="neo-card p-6">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-mono uppercase text-gray-400">Total Liquidity</span>
            <Wallet className="w-5 h-5 text-white" />
          </div>
          <div className="text-3xl font-bold text-white">$78,500.00</div>
          <div className="mt-2 text-sm text-green-400 font-mono flex items-center gap-1">
            <TrendingUp className="w-3 h-3" /> +12.5% this week
          </div>
        </div>

        <div className="neo-card p-6">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-mono uppercase text-gray-400">Active Strategies</span>
            <Layers className="w-5 h-5 text-white" />
          </div>
          <div className="text-3xl font-bold text-white">2</div>
          <div className="mt-2 text-sm text-gray-400 font-mono">Across 2 Chains</div>
        </div>
      </div>

      <div className="space-y-6">
        <h3 className="text-xl font-bold text-white uppercase tracking-wider border-b-2 border-white/20 pb-4">
          Active Positions
        </h3>

        {mockStrategies.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {mockStrategies.map((strategy) => (
              <div
                key={strategy.id}
                onClick={() => setSelectedStrategyId(strategy.id)}
                className="neo-card p-6 hover:bg-white/5 group cursor-pointer relative"
              >
                <div className="absolute top-4 right-4 flex items-center gap-2">
                  <div
                    className={`w-2 h-2 rounded-full ${strategy.status === "active" ? "bg-green-500 animate-pulse" : "bg-gray-500"}`}
                  />
                  <span className="text-xs font-mono uppercase text-gray-400">{strategy.status}</span>
                </div>

                <h4 className="text-2xl font-bold text-white mb-4 group-hover:underline decoration-2 underline-offset-4">
                  {strategy.name}
                </h4>

                <div className="flex items-center gap-3 mb-6">
                  <span className="px-3 py-1 border border-white/30 text-xs font-bold uppercase bg-white/5">
                    {strategy.chainFrom}
                  </span>
                  <ArrowRight className="w-4 h-4 text-gray-500" />
                  <span className="px-3 py-1 border border-white/30 text-xs font-bold uppercase bg-white/5">
                    {strategy.chainTo}
                  </span>
                </div>

                <div className="border-t border-white/10 pt-4">
                  <div className="text-xs text-gray-500 font-mono uppercase mb-1">Liquidity</div>
                  <div className="text-xl font-bold">{strategy.liquidity}</div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="neo-card p-12 text-center border-dashed">
            <Droplet className="w-12 h-12 mx-auto mb-4 text-gray-600" />
            <h3 className="text-xl font-bold text-white mb-2">No Active Strategies</h3>
            <p className="text-gray-400 mb-6">Create your first cross-chain liquidity strategy</p>
            <button className="text-white underline underline-offset-4 hover:text-gray-300">Learn how it works</button>
          </div>
        )}
      </div>
    </div>
  )
}
