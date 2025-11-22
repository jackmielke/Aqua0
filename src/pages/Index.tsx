import { CosmicBackground } from "@/components/CosmicBackground";
import { VibeCatcherGame } from "@/components/VibeCatcherGame";

const Index = () => {
  return (
    <div className="relative min-h-screen cosmic-bg overflow-hidden">
      <CosmicBackground />
      
      <div className="relative z-10 flex flex-col items-center justify-center min-h-screen px-4 py-12">
        <div className="text-center mb-12 animate-float">
          <h1 className="text-7xl md:text-9xl font-bold mb-4 text-glow tracking-tight">
            VIBE MAXING
          </h1>
          <p className="text-xl md:text-2xl text-muted-foreground font-light tracking-wide">
            ETH Global Hackathon
          </p>
        </div>

        <VibeCatcherGame />

        <div className="absolute bottom-8 text-center text-sm text-muted-foreground">
          <p>Built for ETH Global 2025</p>
        </div>
      </div>
    </div>
  );
};

export default Index;
