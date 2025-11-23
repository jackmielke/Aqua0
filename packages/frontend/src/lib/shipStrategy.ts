import { MiniKit } from '@worldcoin/minikit-js'
import { encodeAbiParameters, parseAbiParameters, keccak256, toHex } from 'viem'

// LayerZero Endpoint ID
const EID = import.meta.env.VITE_EID || '30184'

// Contract addresses on Base (where strategies are deployed)
const CONTRACTS_BASE = {
  STABLESWAP: import.meta.env.VITE_STABLESWAP_BASE || '0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E',
  CONCENTRATED_LIQUIDITY: import.meta.env.VITE_CONCENTRATED_BASE || '0xDf12aaAdBaEc2C9cf9E56Bd4B807008530269839',
}

// Composer on WorldChain (handles cross-chain operations)
const COMPOSER_WORLD = import.meta.env.VITE_COMPOSER_WORLD || '0xc689cA9BC4C0176b8a0d50d4733A44Af83834Ae8'

// Token addresses on WorldChain
export const TOKENS = {
  USDC: import.meta.env.VITE_USDC_WORLD || '0x79A02482A880bCE3F13e09Da970dC34db4CD24d1',
  USDT: import.meta.env.VITE_USDT_WORLD || '0x79A02482A880bCE3F13e09Da970dC34db4CD24d1',
  ETH: import.meta.env.VITE_WETH_WORLD || '0x4200000000000000000000000000000000000006',
}

interface ShipStrategyParams {
  strategyType: 'stableswap' | 'concentrated'
  feeBps: number // Fee in basis points (e.g., 30 = 0.30%)
  token0: string // Not used - kept for backwards compatibility
  token1: string // Not used - kept for backwards compatibility
  // Additional params for concentrated liquidity
  priceLower?: string // For concentrated liquidity (in wei)
  priceUpper?: string // For concentrated liquidity (in wei)
  // Additional params for stableswap
  amplificationFactor?: number // For stableswap (A parameter)
}

export async function shipStrategyToChain(params: ShipStrategyParams) {
  const { strategyType, feeBps } = params

  // Get wallet address from localStorage (saved during WorldID auth)
  let maker: string

  try {
    const authData = localStorage.getItem('worldid_auth')
    if (authData) {
      const { wallet_address } = JSON.parse(authData)
      if (wallet_address) {
        maker = wallet_address
        console.log('Maker address from localStorage:', maker)
      } else {
        throw new Error('Wallet address not found')
      }
    } else {
      throw new Error('Not authenticated')
    }
  } catch (error) {
    console.error('Error getting wallet address:', error)

    // Fallback: try to get wallet address from MiniKit
    try {
      const walletAuth = await MiniKit.commandsAsync.walletAuth({
        nonce: Date.now().toString(),
        requestId: Date.now().toString(),
        expirationTime: new Date(Date.now() + 5 * 60 * 1000),
        notBefore: new Date(Date.now()),
        statement: 'Sign to create a cross-chain liquidity strategy',
      })

      if (walletAuth.finalPayload && (walletAuth.finalPayload as any).status === 'success') {
        maker = (walletAuth.finalPayload as any).address
        console.log('Maker address from MiniKit:', maker)

        // Save it to localStorage for next time
        const authData = localStorage.getItem('worldid_auth')
        if (authData) {
          const data = JSON.parse(authData)
          data.wallet_address = maker
          localStorage.setItem('worldid_auth', JSON.stringify(data))
        }
      } else {
        throw new Error('Failed to get wallet address')
      }
    } catch (err) {
      console.error('Fallback wallet auth failed:', err)
      throw new Error('Please authenticate with WorldID to create a strategy')
    }
  }

  // Salt is always 0
  const salt = '0x' + '0'.repeat(64)

  // Determine which contract on Base to target
  const targetContract = strategyType === 'stableswap'
    ? CONTRACTS_BASE.STABLESWAP
    : CONTRACTS_BASE.CONCENTRATED_LIQUIDITY

  // Create canonical token IDs (chain-agnostic identifiers)
  // These match the Solidity script approach
  const token0Id = keccak256(toHex('USDC'))
  const token1Id = keccak256(toHex('USDT'))

  // Build strategy data based on type
  let strategyData: any

  if (strategyType === 'stableswap') {
    const amplificationFactor = params.amplificationFactor || 100
    strategyData = {
      maker,
      token0Id,
      token1Id,
      feeBps,
      amplificationFactor,
      salt,
    }
  } else {
    const priceLower = params.priceLower || '900000000000000000' // 0.9 * 1e18
    const priceUpper = params.priceUpper || '1100000000000000000' // 1.1 * 1e18
    strategyData = {
      maker,
      token0Id,
      token1Id,
      feeBps,
      priceLower,
      priceUpper,
      salt,
    }
  }

  // Import the full ABI
  const ComposerJSON = await import('./AquaStrategyComposer.json')
  const composerABI = ComposerJSON.abi

  console.log('📋 Loaded ABI with', composerABI.length, 'functions')
  console.log('📋 Looking for shipStrategyToChain...', composerABI.find((f: any) => f.name === 'shipStrategyToChain') ? 'FOUND ✅' : 'NOT FOUND ❌')

  try {
    // Encode the strategy data as ABI-encoded bytes
    // This matches how the Solidity contract expects it: abi.encode(strategy)
    let encodedStrategy: `0x${string}`

    if (strategyType === 'stableswap') {
      // Encode stableswap strategy: (address maker, bytes32 token0Id, bytes32 token1Id, uint256 feeBps, uint256 amplificationFactor, bytes32 salt)
      encodedStrategy = encodeAbiParameters(
        parseAbiParameters('address, bytes32, bytes32, uint256, uint256, bytes32'),
        [
          strategyData.maker as `0x${string}`,
          strategyData.token0Id as `0x${string}`,
          strategyData.token1Id as `0x${string}`,
          BigInt(strategyData.feeBps),
          BigInt(strategyData.amplificationFactor),
          strategyData.salt as `0x${string}`,
        ]
      )
    } else {
      // Encode concentrated liquidity strategy: (address maker, bytes32 token0Id, bytes32 token1Id, uint256 feeBps, uint256 priceLower, uint256 priceUpper, bytes32 salt)
      encodedStrategy = encodeAbiParameters(
        parseAbiParameters('address, bytes32, bytes32, uint256, uint256, uint256, bytes32'),
        [
          strategyData.maker as `0x${string}`,
          strategyData.token0Id as `0x${string}`,
          strategyData.token1Id as `0x${string}`,
          BigInt(strategyData.feeBps),
          BigInt(strategyData.priceLower),
          BigInt(strategyData.priceUpper),
          strategyData.salt as `0x${string}`,
        ]
      )
    }

    // Token IDs: canonical identifiers (matching Solidity script)
    const tokenIds = [token0Id, token1Id]

    // Amounts: virtual liquidity for cross-chain bookkeeping
    // Using small amounts like in the Solidity script
    const amounts = [
      BigInt(2_000_000), // 2 USDC (6 decimals)
      BigInt(2_000_000), // 2 USDT (6 decimals)
    ]

    // LayerZero executorLzReceiveOption
    // Format: 0x0003 (option type 3) + 0x00000000000000000000000000000000000000000000000000000000000186a0 (gas limit: 100,000)
    const gasLimit = 200000 // 200k gas for execution on destination
    const gasLimitHex = gasLimit.toString(16).padStart(64, '0')
    const options = '0x0003' + gasLimitHex

    const transactionPayload = {
      address: COMPOSER_WORLD,
      abi: composerABI,
      functionName: 'shipStrategyToChain',
      args: [
        parseInt(EID), // dstEid: Destination chain EID (Base)
        targetContract, // dstApp: Target contract address on Base
        encodedStrategy, // strategy: Encoded strategy data
        tokenIds, // tokenIds: Array of token IDs
        amounts, // amounts: Array of amounts
        options, // options: LayerZero options with gas limit
      ],
      value: '0x' + Math.floor(0.1 * 10**18).toString(16), // 0.1 ETH for LayerZero fees (generous to ensure coverage)
    }

    console.log('🚀 Shipping strategy cross-chain:', {
      type: strategyType,
      dstEid: parseInt(EID),
      dstApp: targetContract,
      strategyEncoded: encodedStrategy,
      strategyData,
      tokenIds,
      amounts,
      options,
      gasLimit,
      value: transactionPayload.value,
    })

    console.log('📱 Sending transaction to MiniKit...')
    // Don't stringify payload with BigInt - just log it directly
    console.log('Transaction payload:', transactionPayload)

    // Add timeout to prevent infinite waiting
    const sendTransactionPromise = MiniKit.commandsAsync.sendTransaction({
      transaction: [transactionPayload],
      formatPayload: false, // CRITICAL: Disable payload formatting to avoid validation errors
    })

    console.log('⏰ Waiting for user response (60s timeout)...')

    const timeoutPromise = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Transaction timeout - user did not respond within 60 seconds')), 60000)
    )

    const { commandPayload, finalPayload } = await Promise.race([
      sendTransactionPromise,
      timeoutPromise
    ]) as any

    console.log('✅ Got response from MiniKit!')
    console.log('Command payload:', commandPayload)
    console.log('Final payload:', finalPayload)

    // Check the status from finalPayload
    if (!finalPayload) {
      throw new Error('No finalPayload received from MiniKit')
    }

    const payload = finalPayload as any

    // Check if user rejected or if there was an error
    if (payload.status === 'error') {
      const errorCode = payload.error_code || 'Unknown error'
      const debugUrl = payload.debug_url
      const errorDetails = payload.details

      console.error('❌ Transaction failed:', {
        error_code: errorCode,
        debug_url: debugUrl,
        details: errorDetails,
        full_payload: payload
      })

      if (errorDetails) {
        console.error('📋 Error details:', JSON.stringify(errorDetails, null, 2))
      }

      throw new Error(`Transaction failed: ${errorCode}${debugUrl ? ` - Debug: ${debugUrl}` : ''}${errorDetails ? ` - ${JSON.stringify(errorDetails)}` : ''}`)
    }

    // Success! Get the transaction ID
    if (payload.status === 'success') {
      const transactionId = payload.transaction_id
      console.log('✅ Transaction ID:', transactionId)
      return {
        success: true,
        txHash: transactionId, // This is the transaction_id, not the hash. Hash comes after confirmation
      }
    }

    // If we get here, status is not success or error (maybe 'pending' or user closed modal?)
    throw new Error(`Unexpected transaction status: ${payload.status || 'undefined'}`)
  } catch (error) {
    console.error('Error shipping strategy:', error)
    throw error
  }
}
