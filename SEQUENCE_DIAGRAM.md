# Aqua0 Cross-Chain Liquidity Protocol - Sequence Diagram

## System Architecture Overview

The Aqua0 protocol enables cross-chain liquidity provisioning and swaps using:
- **Aqua Protocol**: Shared liquidity layer with virtual balances
- **LayerZero**: Cross-chain messaging infrastructure
- **Stargate**: Cross-chain token bridging (OFT standard)
- **World Chain**: Source chain for intents and user interactions
- **Base Chain**: Execution chain with AMM strategies

---

## Flow 1: LP Creates Cross-Chain Strategy (World → Base)

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────┐
│   Frontend  │     │  User Wallet │     │ AquaStrategyComposer│     │   LayerZero DVN      │     │    Aqua     │
│ (World App) │     │ (World Chain)│     │   (World Chain)     │     │    & Executor        │     │(Base Chain) │
└──────┬──────┘     └──────┬───────┘     └──────────┬──────────┘     └──────────┬───────────┘     └──────┬──────┘
       │                   │                         │                            │                        │
       │ 1. User selects   │                         │                            │                        │
       │    strategy type  │                         │                            │                        │
       │    (Stableswap/   │                         │                            │                        │
       │     Concentrated) │                         │                            │                        │
       │                   │                         │                            │                        │
       │ 2. World ID       │                         │                            │                        │
       │    verification   │                         │                            │                        │
       │    (Orb level)    │                         │                            │                        │
       │◄──────────────────┤                         │                            │                        │
       │                   │                         │                            │                        │
       │ 3. walletAuth()   │                         │                            │                        │
       │    to get address │                         │                            │                        │
       │◄──────────────────┤                         │                            │                        │
       │                   │                         │                            │                        │
       │ 4. Build strategy │                         │                            │                        │
       │    struct:        │                         │                            │                        │
       │    - maker        │                         │                            │                        │
       │    - token0/1     │                         │                            │                        │
       │    - feeBps       │                         │                            │                        │
       │    - params       │                         │                            │                        │
       │    - salt         │                         │                            │                        │
       │                   │                         │                            │                        │
       │ 5. quoteShipStrategy()                      │                            │                        │
       │    to get LayerZero fee                     │                            │                        │
       ├───────────────────┼────────────────────────►│                            │                        │
       │                   │                         │                            │                        │
       │◄──────────────────┼─────────────────────────┤                            │                        │
       │    nativeFee      │                         │                            │                        │
       │                   │                         │                            │                        │
       │ 6. sendTransaction()                        │                            │                        │
       │    shipStrategyToChain(                     │                            │                        │
       │      dstEid: BASE_EID,                      │                            │                        │
       │      targetApp: StableswapAMM,              │                            │                        │
       │      strategy: encoded,                     │                            │                        │
       │      tokenIds: [USDC, USDT],                │                            │                        │
       │      amounts: [1000e6, 1000e6],             │                            │                        │
       │      options: executorOptions               │                            │                        │
       │    ) {value: nativeFee}                     │                            │                        │
       ├───────────────────┼────────────────────────►│                            │                        │
       │                   │                         │                            │                        │
       │                   │ 7. Verify tokens        │                            │                        │
       │                   │    exist in registry    │                            │                        │
       │                   │                         │                            │                        │
       │                   │ 8. Encode LZ message:   │                            │                        │
       │                   │    - maker address      │                            │                        │
       │                   │    - target app         │                            │                        │
       │                   │    - encoded strategy   │                            │                        │
       │                   │    - token IDs          │                            │                        │
       │                   │    - amounts            │                            │                        │
       │                   │                         │                            │                        │
       │                   │ 9. _lzSend()            │                            │                        │
       │                   │    to Base chain        │                            │                        │
       │                   ├────────────────────────►│                            │                        │
       │                   │                         │                            │                        │
       │                   │                         │ 10. DVN verifies message   │                        │
       │                   │                         │     across multiple nodes  │                        │
       │                   │                         ├───────────────────────────►│                        │
       │                   │                         │                            │                        │
       │                   │                         │◄───────────────────────────┤                        │
       │                   │                         │     Verification proof     │                        │
       │                   │                         │                            │                        │
       │                   │                         │ 11. Executor delivers msg  │                        │
       │                   │                         │     to Base chain          │                        │
       │                   │                         │                            ├───────────────────────►│
       │                   │                         │                            │                        │
       │                   │                         │                            │ 12. lzReceive()        │
       │                   │                         │                            │     on Base Composer   │
       │                   │                         │                            │                        │
       │                   │                         │◄───────────────────────────┼────────────────────────┤
       │                   │                         │                            │                        │
       │                   │                         │ 13. Decode message         │                        │
       │                   │                         │     Resolve token IDs      │                        │
       │                   │                         │     to Base addresses      │                        │
       │                   │                         │                            │                        │
       │                   │                         │ 14. aqua.shipOnBehalfOf(   │                        │
       │                   │                         │       maker,               │                        │
       │                   │                         │       StableswapAMM,       │                        │
       │                   │                         │       strategy,            │                        │
       │                   │                         │       [USDC, USDT],        │                        │
       │                   │                         │       [1000e6, 1000e6]     │                        │
       │                   │                         │     )                      │                        │
       │                   │                         ├────────────────────────────┼───────────────────────►│
       │                   │                         │                            │                        │
       │                   │                         │                            │ 15. Verify delegate    │
       │                   │                         │                            │     is trusted         │
       │                   │                         │                            │                        │
       │                   │                         │                            │ 16. Calculate hash:    │
       │                   │                         │                            │     keccak256(strategy)│
       │                   │                         │                            │                        │
       │                   │                         │                            │ 17. Store virtual      │
       │                   │                         │                            │     balances:          │
       │                   │                         │                            │     _balances[maker]   │
       │                   │                         │                            │       [app][hash]      │
       │                   │                         │                            │       [token] = amount │
       │                   │                         │                            │                        │
       │                   │                         │◄───────────────────────────┼────────────────────────┤
       │                   │                         │     strategyHash           │                        │
       │                   │                         │                            │                        │
       │◄──────────────────┼─────────────────────────┤                            │                        │
       │   Event: CrossChainShipExecuted             │                            │                        │
       │                   │                         │                            │                        │
       │ 18. Display       │                         │                            │                        │
       │     success UI    │                         │                            │                        │
       │                   │                         │                            │                        │
```

**Key Points:**
- LP's tokens remain in their wallet on World Chain (no custody)
- Only virtual balances are tracked on Base Chain
- Strategy is immutable once shipped
- Composer acts as trusted delegate to ship on behalf of LP

---

## Flow 2: Trader Executes Cross-Chain Swap (World → Base → World)

```
┌─────────────┐  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  ┌─────────────┐  ┌──────────────┐
│   Frontend  │  │ User Wallet  │  │ IntentPool  │  │   Stargate   │  │ CrossChainSwap   │  │    Aqua     │  │ StableswapAMM│
│ (World App) │  │(World Chain) │  │(World Chain)│  │   (OFT)      │  │   Composer       │  │(Base Chain) │  │ (Base Chain) │
└──────┬──────┘  └──────┬───────┘  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘  └──────┬──────┘  └──────┬───────┘
       │                │                  │                │                   │                   │                │
       │ 1. User enters │                  │                │                   │                   │                │
       │    swap details│                  │                │                   │                   │                │
       │    - tokenIn: USDT                │                │                   │                   │                │
       │    - tokenOut: rUSD               │                │                   │                   │                │
       │    - amount: 100                  │                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │ 2. Query available                │                │                   │                   │                │
       │    strategies from                │                │                   │                   │                │
       │    Supabase DB │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │◄───────────────┤                  │                │                   │                   │                │
       │   List of LPs  │                  │                │                   │                   │                │
       │   with quotes  │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │ 3. User selects│                  │                │                   │                   │                │
       │    best quote  │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │ 4. submitIntent()                 │                │                   │                   │                │
       ├────────────────┼─────────────────►│                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │ 5. transferFrom( │                │                   │                   │                │
       │                │    trader,       │                │                   │                   │                │
       │                │    IntentPool,   │                │                   │                   │                │
       │                │    USDT,         │                │                   │                   │                │
       │                │    100e6         │                │                   │                   │                │
       │                │    )             │                │                   │                   │                │
       │                ├─────────────────►│                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │ 6. Store intent:                  │                   │                │
       │                │                  │    - id: hash  │                   │                   │                │
       │                │                  │    - trader    │                   │                   │                │
       │                │                  │    - strategyHash                 │                   │                │
       │                │                  │    - status: PENDING              │                   │                │
       │                │                  │                │                   │                   │                │
       │◄───────────────┼──────────────────┤                │                   │                   │                │
       │   Event: IntentSubmitted          │                │                   │                   │                │
       │   intentId     │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │ [LP monitors intents via frontend]│                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │ 7. LP calls fulfillIntent()       │                │                   │                   │                │
       │    with actualOut                 │                │                   │                   │                │
       ├────────────────┼─────────────────►│                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │ 8. transferFrom( │                │                   │                   │                │
       │                │    LP,           │                │                   │                   │                │
       │                │    IntentPool,   │                │                   │                   │                │
       │                │    rUSD,         │                │                   │                   │                │
       │                │    99.7e6        │                │                   │                   │                │
       │                │    )             │                │                   │                   │                │
       │                ├─────────────────►│                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │ 9. Update intent:                 │                   │                │
       │                │                  │    status = MATCHED               │                   │                │
       │                │                  │    actualOut = 99.7               │                   │                │
       │                │                  │                │                   │                   │                │
       │◄───────────────┼──────────────────┤                │                   │                   │                │
       │   Event: IntentFulfilled          │                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │ 10. Anyone calls settleIntent()   │                │                   │                   │                │
       ├────────────────┼─────────────────►│                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │ 11. Approve tokens                │                   │                │
       │                │                  │     to Stargate│                   │                   │                │
       │                │                  ├───────────────►│                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │ 12. Build compose payload:        │                   │                │
       │                │                  │     - intentId │                   │                   │                │
       │                │                  │     - trader   │                   │                   │                │
       │                │                  │     - LP       │                   │                   │                │
       │                │                  │     - strategyHash                │                   │                │
       │                │                  │     - amounts  │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │ 13. Stargate.send()               │                   │                │
       │                │                  │     Part 1: LP's rUSD             │                   │                │
       │                │                  │     (for trader)                  │                   │                │
       │                │                  ├───────────────►│                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │ 14. Bridge rUSD   │                   │                │
       │                │                  │                │     World → Base  │                   │                │
       │                │                  │                ├──────────────────►│                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │ 15. Stargate.send()               │                   │                │
       │                │                  │     Part 2: Trader's USDT         │                   │                │
       │                │                  │     (for swap)│                   │                   │                │
       │                │                  ├───────────────►│                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │ 16. Bridge USDT   │                   │                │
       │                │                  │                │     World → Base  │                   │                │
       │                │                  │                ├──────────────────►│                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │ 17. lzCompose()   │                │
       │                │                  │                │                   │     receives rUSD │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │ 18. Store in      │                │
       │                │                  │                │                   │     pendingSwaps  │                │
       │                │                  │                │                   │     mapping       │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │ 19. lzCompose()   │                │
       │                │                  │                │                   │     receives USDT │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │ 20. Check both    │                │
       │                │                  │                │                   │     tokens arrived│                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │ 21. pullOnBehalfOf(               │
       │                │                  │                │                   │       LP,         │                │
       │                │                  │                │                   │       composer,   │                │
       │                │                  │                │                   │       strategyHash,               │
       │                │                  │                │                   │       rUSD,       │                │
       │                │                  │                │                   │       99.7e6,     │                │
       │                │                  │                │                   │       composer    │                │
       │                │                  │                │                   │     )             │                │
       │                │                  │                │                   ├──────────────────►│                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │ 22. Reduce LP's│
       │                │                  │                │                   │                   │     virtual    │
       │                │                  │                │                   │                   │     balance    │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │◄──────────────────┤                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │ 23. Approve rUSD  │                │
       │                │                  │                │                   │     to Aqua       │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │ 24. swapExactIn(  │                │
       │                │                  │                │                   │       strategy,   │                │
       │                │                  │                │                   │       true,       │                │
       │                │                  │                │                   │       100e6,      │                │
       │                │                  │                │                   │       99.5e6,     │                │
       │                │                  │                │                   │       composer,   │                │
       │                │                  │                │                   │       ""          │                │
       │                │                  │                │                   │     )             │                │
       │                │                  │                │                   ├───────────────────┼───────────────►│
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │ 25. Get virtual│
       │                │                  │                │                   │                   │     balances   │
       │                │                  │                │                   │                   ├───────────────►│
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │◄───────────────┤
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │ 26. Calculate  │
       │                │                  │                │                   │                   │     amountOut  │
       │                │                  │                │                   │                   │     using      │
       │                │                  │                │                   │                   │     Stableswap │
       │                │                  │                │                   │                   │     formula    │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │ 27. aqua.pull( │
       │                │                  │                │                   │                   │       LP,      │
       │                │                  │                │                   │                   │       hash,    │
       │                │                  │                │                   │                   │       USDT,    │
       │                │                  │                │                   │                   │       99.7e6,  │
       │                │                  │                │                   │                   │       composer │
       │                │                  │                │                   │                   │     )          │
       │                │                  │                │                   │                   ├───────────────►│
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │ 28. Transfer   │
       │                │                  │                │                   │                   │     from LP's  │
       │                │                  │                │                   │                   │     wallet     │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │◄──────────────────┼────────────────┤
       │                │                  │                │                   │   USDT tokens     │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │ 29. stableswapCallback()          │
       │                │                  │                │                   │     (push USDT)   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │ 30. pushOnBehalfOf(               │
       │                │                  │                │                   │       LP,         │                │
       │                │                  │                │                   │       composer,   │                │
       │                │                  │                │                   │       AMM,        │                │
       │                │                  │                │                   │       hash,       │                │
       │                │                  │                │                   │       rUSD,       │                │
       │                │                  │                │                   │       100e6       │                │
       │                │                  │                │                   │     )             │                │
       │                │                  │                │                   ├──────────────────►│                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │ 31. Increase   │
       │                │                  │                │                   │                   │     LP's rUSD  │
       │                │                  │                │                   │                   │     balance    │
       │                │                  │                │                   │                   │                │
       │                │                  │                │                   │◄──────────────────┤                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │◄──────────────────┤                   │                │
       │                │                  │   Swap complete│                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │ 32. Bridge USDT   │                   │                │
       │                │                  │                │     back to World │                   │                │
       │                │                  │                │     (to LP)       │                   │                │
       │                │                  │◄───────────────┤                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │                │ 33. Bridge rUSD   │                   │                │
       │                │                  │                │     back to World │                   │                │
       │                │                  │                │     (to Trader)   │                   │                │
       │                │                  │◄───────────────┤                   │                   │                │
       │                │                  │                │                   │                   │                │
       │                │                  │ 34. Distribute tokens:            │                   │                │
       │                │                  │     - USDT → LP                   │                   │                │
       │                │                  │     - rUSD → Trader               │                   │                │
       │                │                  │                │                   │                   │                │
       │◄───────────────┼──────────────────┤                │                   │                   │                │
       │   rUSD received│                  │                │                   │                   │                │
       │                │                  │                │                   │                   │                │
       │ 35. Display    │                  │                │                   │                   │                │
       │     success UI │                  │                │                   │                   │                │
       │                │                  │                │                   │                   │                │
```

**Key Points:**
- Intent-based architecture: Trader submits intent, LP fulfills
- Dual token bridge: Both tokens sent to Base for atomic swap
- Composer acts as trusted delegate for Aqua operations
- LP's tokens never leave their wallet (pulled during swap execution)
- Atomic execution: Both parties receive tokens or transaction reverts

---

## Flow 3: Direct Swap on Base Chain (Local)

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│   Trader    │     │ StableswapAMM│     │    Aqua      │     │  LP Wallet  │     │  Trader      │
│  Contract   │     │ (Base Chain) │     │ (Base Chain) │     │(Base Chain) │     │   Wallet     │
└──────┬──────┘     └──────┬───────┘     └──────┬───────┘     └──────┬──────┘     └──────┬───────┘
       │                   │                     │                    │                   │
       │ 1. swapExactIn(   │                     │                    │                   │
       │      strategy,    │                     │                    │                   │
       │      zeroForOne,  │                     │                    │                   │
       │      amountIn,    │                     │                    │                   │
       │      amountOutMin,│                     │                    │                   │
       │      recipient,   │                     │                    │                   │
       │      takerData    │                     │                    │                   │
       │    )              │                     │                    │                   │
       ├──────────────────►│                     │                    │                   │
       │                   │                     │                    │                   │
       │                   │ 2. Calculate hash:  │                    │                   │
       │                   │    keccak256(strategy)                   │                   │
       │                   │                     │                    │                   │
       │                   │ 3. Lock strategy    │                    │                   │
       │                   │    (reentrancy guard)                    │                   │
       │                   │                     │                    │                   │
       │                   │ 4. safeBalances()   │                    │                   │
       │                   │    Get virtual balances                  │                   │
       │                   ├────────────────────►│                    │                   │
       │                   │                     │                    │                   │
       │                   │◄────────────────────┤                    │                   │
       │                   │  balanceIn, balanceOut                   │                   │
       │                   │                     │                    │                   │
       │                   │ 5. Calculate amountOut                   │                   │
       │                   │    using Stableswap formula:             │                   │
       │                   │    weight = A/(A+1) │                    │                   │
       │                   │    out = weight*constantSum +            │                   │
       │                   │          (1-weight)*constantProduct      │                   │
       │                   │                     │                    │                   │
       │                   │ 6. Verify amountOut >= amountOutMin      │                   │
       │                   │                     │                    │                   │
       │                   │ 7. pull(            │                    │                   │
       │                   │      maker,         │                    │                   │
       │                   │      strategyHash,  │                    │                   │
       │                   │      tokenOut,      │                    │                   │
       │                   │      amountOut,     │                    │                   │
       │                   │      recipient      │                    │                   │
       │                   │    )                │                    │                   │
       │                   ├────────────────────►│                    │                   │
       │                   │                     │                    │                   │
       │                   │                     │ 8. Reduce virtual  │                   │
       │                   │                     │    balance         │                   │
       │                   │                     │                    │                   │
       │                   │                     │ 9. transferFrom(   │                   │
       │                   │                     │      LP,           │                   │
       │                   │                     │      recipient,    │                   │
       │                   │                     │      tokenOut,     │                   │
       │                   │                     │      amountOut     │                   │
       │                   │                     │    )               │                   │
       │                   │                     ├───────────────────►│                   │
       │                   │                     │                    │                   │
       │                   │                     │                    ├──────────────────►│
       │                   │                     │                    │  tokenOut         │
       │                   │                     │                    │                   │
       │                   │◄────────────────────┤                    │                   │
       │                   │                     │                    │                   │
       │                   │ 10. stableswapCallback()                 │                   │
       │                   │     (to trader contract)                 │                   │
       │◄──────────────────┤                     │                    │                   │
       │                   │                     │                    │                   │
       │ 11. Approve tokenIn                     │                    │                   │
       │     to Aqua       │                     │                    │                   │
       ├─────────────────────────────────────────►│                   │                   │
       │                   │                     │                    │                   │
       │ 12. push(         │                     │                    │                   │
       │       maker,      │                     │                    │                   │
       │       app,        │                     │                    │                   │
       │       strategyHash,                     │                    │                   │
       │       tokenIn,    │                     │                    │                   │
       │       amountIn    │                     │                    │                   │
       │     )             │                     │                    │                   │
       ├─────────────────────────────────────────►│                   │                   │
       │                   │                     │                    │                   │
       │                   │                     │ 13. transferFrom(  │                   │
       │                   │                     │       trader,      │                   │
       │                   │                     │       Aqua,        │                   │
       │                   │                     │       tokenIn,     │                   │
       │                   │                     │       amountIn     │                   │
       │                   │                     │     )              │                   │
       │◄─────────────────────────────────────────┤                   │                   │
       │                   │                     │                    │                   │
       │                   │                     │ 14. Increase virtual                   │
       │                   │                     │     balance        │                   │
       │                   │                     │                    │                   │
       │                   │ 15. _safeCheckAquaPush()                 │                   │
       │                   │     Verify balance increased             │                   │
       │                   ├────────────────────►│                    │                   │
       │                   │                     │                    │                   │
       │                   │◄────────────────────┤                    │                   │
       │                   │                     │                    │                   │
       │                   │ 16. Unlock strategy │                    │                   │
       │                   │     (reentrancy guard)                   │                   │
       │                   │                     │                    │                   │
       │◄──────────────────┤                     │                    │                   │
       │   amountOut       │                     │                    │                   │
       │                   │                     │                    │                   │
```

**Key Points:**
- Direct swap without cross-chain messaging
- LP's tokens pulled from wallet only during swap execution
- Trader's tokens pushed to LP's virtual balance via callback
- Reentrancy protection ensures atomic execution
- Virtual balance accounting (no token custody by Aqua)

---

## Component Roles Summary

| Component | Chain | Role |
|-----------|-------|------|
| **Frontend (World App)** | World Chain | User interface for LP strategy creation and trader swaps |
| **World ID** | World Chain | User verification (Orb level) and wallet authentication |
| **AquaStrategyComposer** | World Chain | Initiates cross-chain strategy shipping via LayerZero |
| **IntentPool** | World Chain | Matches trader intents with LP strategies |
| **Stargate (OFT)** | Both Chains | Bridges tokens cross-chain using LayerZero |
| **LayerZero DVN** | Off-chain | Verifies messages across multiple oracle nodes |
| **LayerZero Executor** | Off-chain | Delivers verified messages to destination chain |
| **CrossChainSwapComposer** | Base Chain | Receives bridged tokens and executes swaps |
| **Aqua** | Base Chain | Shared liquidity layer with virtual balance accounting |
| **StableswapAMM** | Base Chain | Stablecoin AMM strategy (Curve-style formula) |
| **ConcentratedLiquiditySwap** | Base Chain | Concentrated liquidity AMM (Uniswap v3-style) |
| **Supabase** | Off-chain | Database for strategy indexing and discovery |

---

## Key Innovations

1. **No Token Custody**: LP tokens remain in wallets, only virtual balances tracked
2. **Cross-Chain Liquidity**: Single LP position serves traders on multiple chains
3. **Intent-Based Architecture**: Traders submit intents, LPs fulfill asynchronously
4. **Trusted Delegates**: Composers can act on behalf of LPs for cross-chain operations
5. **Immutable Strategies**: Once shipped, parameters cannot change (safety + simplicity)
6. **Atomic Swaps**: Pull/push pattern ensures all-or-nothing execution
7. **Capital Efficiency**: Same capital backs multiple strategies simultaneously

---

## Security Considerations

1. **Reentrancy Protection**: Per-strategy locks prevent nested swaps
2. **Trusted Delegate System**: Only whitelisted contracts can act on behalf of LPs
3. **Virtual Balance Verification**: `safeBalances()` ensures tokens are in active strategy
4. **LayerZero Security**: DVN verification + Executor delivery separation
5. **Slippage Protection**: `amountOutMin` / `amountInMax` parameters
6. **Strategy Immutability**: Prevents parameter manipulation after shipping
7. **Intent Expiry**: Deadlines prevent stale intent execution

---

## Gas Optimization

1. **Virtual Balances**: No token transfers until swap execution
2. **Transient Storage**: Reentrancy locks use transient storage (EIP-1153)
3. **Batch Operations**: Multicall support for multiple operations
4. **Efficient Encoding**: Canonical token IDs reduce cross-chain message size
5. **IR Optimization**: Contracts compiled with `via_ir = true`

---

*Generated for Aqua0 Protocol - Cross-Chain Liquidity Infrastructure*


