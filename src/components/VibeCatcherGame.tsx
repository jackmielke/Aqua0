import { useState, useEffect, useCallback } from "react";
import { Button } from "@/components/ui/button";

interface Vibe {
  id: number;
  x: number;
  y: number;
  size: number;
  opacity: number;
}

export const VibeCatcherGame = () => {
  const [score, setScore] = useState(0);
  const [vibes, setVibes] = useState<Vibe[]>([]);
  const [isPlaying, setIsPlaying] = useState(false);
  const [highScore, setHighScore] = useState(0);

  const spawnVibe = useCallback(() => {
    const newVibe: Vibe = {
      id: Date.now(),
      x: Math.random() * 80 + 10, // 10-90% of screen width
      y: Math.random() * 70 + 10, // 10-80% of screen height
      size: 40 + Math.random() * 30,
      opacity: 1,
    };
    setVibes((prev) => [...prev, newVibe]);

    // Remove vibe after 2.5 seconds if not clicked
    setTimeout(() => {
      setVibes((prev) => prev.filter((v) => v.id !== newVibe.id));
    }, 2500);
  }, []);

  const handleVibeClick = (vibeId: number) => {
    setScore((prev) => prev + 10);
    setVibes((prev) => prev.filter((v) => v.id !== vibeId));
  };

  const startGame = () => {
    setScore(0);
    setVibes([]);
    setIsPlaying(true);
  };

  const stopGame = () => {
    setIsPlaying(false);
    if (score > highScore) {
      setHighScore(score);
    }
    setVibes([]);
  };

  useEffect(() => {
    if (!isPlaying) return;

    const interval = setInterval(() => {
      spawnVibe();
    }, 1000);

    const gameTimer = setTimeout(() => {
      stopGame();
    }, 30000); // 30 second game

    return () => {
      clearInterval(interval);
      clearTimeout(gameTimer);
    };
  }, [isPlaying, spawnVibe]);

  return (
    <div className="relative w-full max-w-4xl mx-auto">
      <div className="flex flex-col items-center gap-6 mb-8">
        <div className="flex gap-8 text-center">
          <div>
            <div className="text-sm text-muted-foreground mb-1">Score</div>
            <div className="text-4xl font-bold text-glow">{score}</div>
          </div>
          {highScore > 0 && (
            <div>
              <div className="text-sm text-muted-foreground mb-1">High Score</div>
              <div className="text-2xl font-semibold text-primary">{highScore}</div>
            </div>
          )}
        </div>

        {!isPlaying ? (
          <Button
            onClick={startGame}
            size="lg"
            className="bg-primary hover:bg-primary/90 text-primary-foreground font-semibold text-lg px-8 py-6 rounded-full hover-glow"
          >
            Start Catching Vibes
          </Button>
        ) : (
          <Button
            onClick={stopGame}
            size="lg"
            variant="secondary"
            className="font-semibold px-8 py-6 rounded-full"
          >
            Stop Game
          </Button>
        )}
      </div>

      <div className="relative w-full h-[500px] border-2 border-primary/30 rounded-2xl bg-card/30 backdrop-blur-sm overflow-hidden">
        {!isPlaying && vibes.length === 0 && (
          <div className="absolute inset-0 flex items-center justify-center">
            <p className="text-muted-foreground text-center px-4">
              Click the glowing vibes as fast as you can!<br />
              <span className="text-sm">You have 30 seconds. Each vibe is worth 10 points.</span>
            </p>
          </div>
        )}

        {vibes.map((vibe) => (
          <button
            key={vibe.id}
            onClick={() => handleVibeClick(vibe.id)}
            className="absolute rounded-full bg-primary cursor-pointer transition-all duration-200 hover:scale-110 animate-pulse-glow"
            style={{
              left: `${vibe.x}%`,
              top: `${vibe.y}%`,
              width: `${vibe.size}px`,
              height: `${vibe.size}px`,
              transform: "translate(-50%, -50%)",
              boxShadow: "0 0 30px hsl(var(--cosmic-glow))",
              opacity: vibe.opacity,
            }}
            aria-label="Catch this vibe"
          />
        ))}
      </div>
    </div>
  );
};
