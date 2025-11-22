# Vibe Maxing

An interactive web experience built for ETH Global Hackathon.

## Tech Stack

- React 18 with TypeScript
- Vite for blazing fast development
- Tailwind CSS for styling
- shadcn-ui components

## Getting Started

### Prerequisites

- Node.js 18+ and pnpm (recommended) or npm

### Installation

```sh
# Clone the repository
git clone <YOUR_GIT_URL>
cd <YOUR_PROJECT_NAME>

# Install dependencies with pnpm (recommended)
pnpm install

# Or with npm
npm install

# Start development server
pnpm dev
# Or: npm run dev
```

The app will be available at `http://localhost:8080`

## Available Scripts

- `pnpm dev` - Start development server
- `pnpm build` - Build for production
- `pnpm preview` - Preview production build locally
- `pnpm lint` - Run ESLint

## PNPM Monorepo Compatibility

This project is fully compatible with PNPM monorepos. The workspace uses:
- Shared dependencies via PNPM workspace protocol
- Hoisted node_modules for optimal disk usage
- Fast, deterministic installs with proper peer dependency handling

To use in a monorepo, add this to your root `pnpm-workspace.yaml`:
```yaml
packages:
  - 'packages/*'
  - 'apps/*'
```

## Project Structure

```
src/
├── components/     # React components
├── pages/          # Page components
├── hooks/          # Custom React hooks
├── lib/            # Utilities
└── index.css       # Global styles & design tokens
```

## Deployment

Build the project for production:
```sh
pnpm build
```

The `dist` folder will contain the production-ready static files.

## License

MIT
