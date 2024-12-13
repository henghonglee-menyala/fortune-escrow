const { ethers } = require('ethers');
require('dotenv').config();
const fs = require('fs');
const path = require('path');

// Read and parse the contract ABI and bytecode
const contractPath = path.join(__dirname, 'out/UnownedEscrowV1.sol/UnownedEscrowV1.json');
const contractJson = JSON.parse(fs.readFileSync(contractPath));

async function main() {
    // Connect to the network using the RPC URL from .env
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    // Create a wallet instance using the private key from .env
    const deployer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    // Deploy the contract
    console.log("Deploying UnownedEscrowV1...");
    const factory = new ethers.ContractFactory(
        contractJson.abi,
        contractJson.bytecode,
        deployer
    );

    // Define contract parameters
    const xsgd = "0xDC3326e71D45186F113a2F448984CA0e8D201995";
    const usdc = "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359"; 
    const uniswapRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

    // Deploy and wait for deployment to finish
    const contract = await factory.deploy(
        process.env.SRC,
        process.env.DEST,
        xsgd,
        usdc,
        uniswapRouter
    );
    await contract.waitForDeployment();
    console.log("Contract deployed to:", await contract.getAddress());
    
    console.log("Deployment complete!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
