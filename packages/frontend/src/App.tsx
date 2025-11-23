import { useState, useEffect } from "react"
import { Toaster } from "@/components/ui/toaster"
import { Toaster as Sonner } from "@/components/ui/sonner"
import { TooltipProvider } from "@/components/ui/tooltip"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { MarketMakersTab } from "@/components/market-makers-tab"
import { SwapTab } from "@/components/swap-tab"
import { LayoutGrid, ArrowLeftRight, LogOut } from "lucide-react"
import MiniKitProvider from "@/components/MiniKitProvider"
import LandingPage from "@/components/LandingPage"
import "./index.css"

const queryClient = new QueryClient()

const App = () => {
  const [activeTab, setActiveTab] = useState<"market-makers" | "swap">("market-makers")
  const [isVerified, setIsVerified] = useState(false)

  useEffect(() => {
    // Check if user is already verified
    const authData = localStorage.getItem('worldid_auth')
    if (authData) {
      const { verified } = JSON.parse(authData)
      setIsVerified(verified)
    }
  }, [])

  const handleLogout = () => {
    localStorage.clear()
    window.location.reload()
  }

  // Show LandingPage if not verified
  if (!isVerified) {
    return (
      <MiniKitProvider>
        <QueryClientProvider client={queryClient}>
          <TooltipProvider>
            <Toaster />
            <Sonner />
            <LandingPage onSuccess={() => setIsVerified(true)} />
          </TooltipProvider>
        </QueryClientProvider>
      </MiniKitProvider>
    )
  }

  return (
    <MiniKitProvider>
      <QueryClientProvider client={queryClient}>
        <TooltipProvider>
          <Toaster />
          <Sonner />
        <main className="min-h-screen bg-black text-white font-sans space-bg pb-24 md:pb-0 md:pl-64 relative overflow-hidden">
          {/* Desktop Sidebar */}
          <aside className="hidden md:flex fixed left-0 top-0 bottom-0 w-64 bg-black border-r-2 border-white flex-col z-50">
            <div className="p-6 border-b-2 border-white">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 border-2 border-white bg-black flex items-center justify-center">
                  <img
                    src="/aqua0-logo.png"
                    alt="Aqua0 Logo"
                    width={32}
                    height={32}
                    className="w-8 h-8 object-contain invert"
                  />
                </div>
                <h1 className="text-2xl font-bold tracking-tighter">AQUA0</h1>
              </div>
            </div>

            <nav className="flex-1 p-6 space-y-4">
              <button
                onClick={() => setActiveTab("market-makers")}
                className={`w-full flex items-center gap-4 px-4 py-4 border-2 transition-all duration-200 group ${
                  activeTab === "market-makers"
                    ? "bg-white text-black border-white shadow-[4px_4px_0px_0px_#ffffff]"
                    : "bg-black text-white border-transparent hover:border-white hover:shadow-[4px_4px_0px_0px_#ffffff]"
                }`}
              >
                <LayoutGrid className="w-5 h-5" strokeWidth={2} />
                <span className="font-bold tracking-wide uppercase">Strategies</span>
              </button>

              <button
                onClick={() => setActiveTab("swap")}
                className={`w-full flex items-center gap-4 px-4 py-4 border-2 transition-all duration-200 group ${
                  activeTab === "swap"
                    ? "bg-white text-black border-white shadow-[4px_4px_0px_0px_#ffffff]"
                    : "bg-black text-white border-transparent hover:border-white hover:shadow-[4px_4px_0px_0px_#ffffff]"
                }`}
              >
                <ArrowLeftRight className="w-5 h-5" strokeWidth={2} />
                <span className="font-bold tracking-wide uppercase">Swap</span>
              </button>
            </nav>

            <div className="p-6 border-t-2 border-white space-y-4">
              <button
                onClick={handleLogout}
                className="w-full flex items-center gap-4 px-4 py-4 border-2 border-white bg-black text-white hover:bg-white hover:text-black transition-all duration-200"
              >
                <LogOut className="w-5 h-5" strokeWidth={2} />
                <span className="font-bold tracking-wide uppercase">Logout</span>
              </button>
              <div className="text-xs font-mono text-gray-400 text-center">AQUA0 V1.0 // WORLDCHAIN</div>
            </div>
          </aside>

          {/* Mobile Header */}
          <header className="md:hidden fixed top-0 left-0 right-0 bg-black border-b-2 border-white z-40 p-4">
            <div className="flex items-center justify-center gap-3">
              <div className="w-8 h-8 border-2 border-white flex items-center justify-center bg-black">
                <img
                  src="/aqua0-logo.png"
                  alt="Aqua0 Logo"
                  width={20}
                  height={20}
                  className="w-5 h-5 object-contain invert"
                />
              </div>
              <h1 className="text-xl font-bold tracking-tighter">AQUA0</h1>
            </div>
          </header>

          {/* Main Content Area */}
          <div className="pt-20 md:pt-0 min-h-screen">
            {activeTab === "market-makers" && (
              <div className="max-w-7xl mx-auto animate-in fade-in slide-in-from-bottom-4 duration-500">
                <MarketMakersTab />
              </div>
            )}

            {activeTab === "swap" && (
              <div className="max-w-3xl mx-auto animate-in fade-in slide-in-from-bottom-4 duration-500">
                <SwapTab />
              </div>
            )}
          </div>

          {/* Mobile Bottom Navigation */}
          <nav className="fixed bottom-0 left-0 right-0 bg-black border-t-2 border-white z-50 md:hidden">
            <div className="grid grid-cols-3 h-20">
              <button
                onClick={() => setActiveTab("market-makers")}
                className={`flex flex-col items-center justify-center gap-1 border-r-2 border-white/20 transition-colors ${
                  activeTab === "market-makers" ? "bg-white text-black" : "text-white hover:bg-white/10"
                }`}
              >
                <LayoutGrid className="w-6 h-6" strokeWidth={2} />
                <span className="text-[10px] font-bold uppercase tracking-wider">Strategies</span>
              </button>
              <button
                onClick={() => setActiveTab("swap")}
                className={`flex flex-col items-center justify-center gap-1 border-r-2 border-white/20 transition-colors ${
                  activeTab === "swap" ? "bg-white text-black" : "text-white hover:bg-white/10"
                }`}
              >
                <ArrowLeftRight className="w-6 h-6" strokeWidth={2} />
                <span className="text-[10px] font-bold uppercase tracking-wider">Swap</span>
              </button>
              <button
                onClick={handleLogout}
                className="flex flex-col items-center justify-center gap-1 text-white hover:bg-white/10 transition-colors"
              >
                <LogOut className="w-6 h-6" strokeWidth={2} />
                <span className="text-[10px] font-bold uppercase tracking-wider">Logout</span>
              </button>
            </div>
          </nav>
        </main>
        </TooltipProvider>
      </QueryClientProvider>
    </MiniKitProvider>
  )
}

export default App
