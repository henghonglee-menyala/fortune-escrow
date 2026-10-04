# Fortune Escrow

Fortune Escrow is a Solidity escrow contract that holds XSGD from a source account, swaps it for USDC through Uniswap V3, then lets the destination account receive the USDC or return the tokens to the source. The repository contains the `UnownedEscrowV1` contract and a Node.js script for deploying it to Polygon.

## Requirements

- Git with submodule support
- [Foundry](https://book.getfoundry.sh/) (`forge`, `cast`, and `anvil`)
- Node.js 18 or later and Yarn

## Set up

Clone the repository with its Solidity dependencies and install the Node.js packages:

```sh
git clone --recurse-submodules https://github.com/henghonglee-menyala/fortune-escrow.git
cd fortune-escrow
yarn install
```

If you already cloned without submodules, run `git submodule update --init --recursive`.

## Compile and check locally

Compile the contract with Foundry:

```sh
forge build
```

The repository does not currently define a test suite. To exercise deployment and verify the constructor configuration on a disposable local Anvil chain, run:

```sh
export PATH="$HOME/.foundry/bin:$PATH"
export FOUNDRY_SOLC="${FOUNDRY_SOLC:-0.8.37}"

anvil --port 8545 --silent &
ANVIL_PID=$!
trap 'kill "$ANVIL_PID" 2>/dev/null || true' EXIT
RPC=http://127.0.0.1:8545

# Wait for Anvil to accept requests.
until cast block-number --rpc-url "$RPC" >/dev/null 2>&1; do sleep 1; done

# These are Anvil's published development accounts and are safe only on this local chain.
DEV_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
SRC=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
DEST=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
XSGD=0xDC3326e71D45186F113a2F448984CA0e8D201995
USDC=0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
ROUTER=0xE592427A0AEce92De3Edee1F18E0157C05861564

ADDR=$(forge create src/UnownedEscrowV1.sol:UnownedEscrowV1 \
  --rpc-url "$RPC" --private-key "$DEV_KEY" --broadcast \
  --constructor-args "$SRC" "$DEST" "$XSGD" "$USDC" "$ROUTER" \
  | awk '/Deployed to:/ {print $3}')

test -n "$ADDR"
cast call "$ADDR" 'src()(address)' --rpc-url "$RPC"
cast call "$ADDR" 'dest()(address)' --rpc-url "$RPC"
cast call "$ADDR" 'srcToken()(address)' --rpc-url "$RPC"
cast call "$ADDR" 'destToken()(address)' --rpc-url "$RPC"
cast call "$ADDR" 'swapRouter()(address)' --rpc-url "$RPC"
cast codesize "$ADDR" --rpc-url "$RPC"
```

Compare the five returned addresses with `SRC`, `DEST`, `XSGD`, `USDC`, and `ROUTER`; the code size should be greater than zero. Anvil's development key must never be used on a public network.

## Deploy to Polygon

`index.js` deploys the compiled artifact at `out/UnownedEscrowV1.sol/UnownedEscrowV1.json`. Build first, then create a `.env` file in the repository root with an RPC endpoint and deployer key:

```dotenv
RPC_URL=https://your-polygon-rpc-endpoint
PRIVATE_KEY=your-funded-deployer-private-key
SRC=0xYourSourceAddress
DEST=0xYourDestinationAddress
```

Keep `.env` private and never commit a real private key. The deployment script uses XSGD at `0xDC3326e71D45186F113a2F448984CA0e8D201995`, USDC at `0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359`, and the Uniswap V3 router at `0xE592427A0AEce92De3Edee1F18E0157C05861564`; those addresses are fixed in `index.js`. Deploy with:

```sh
forge build
node index.js
```

The script prints the deployed contract address. Confirm that the token and router addresses are appropriate for the target network before deployment.

## Contract behavior

The constructor stores the payable source and destination addresses, the source and destination ERC-20 tokens, and the Uniswap V3 swap router. `fixedSrcSwap` performs an exact-input swap with a minimum output; `fixedDestSwap` performs an exact-output swap with a maximum input. Both use the 0.05% fee tier and assume source tokens have already been deposited into the contract. `withdraw` transfers destination tokens to `dest`, while `refund` sends the contract's remaining source and destination token balances to `src`.

The contract currently has no caller access controls: these public functions can be called by anyone, and withdrawals/refunds always send funds to the configured recipient. Review the contract and its assumptions carefully before using it with real funds.
