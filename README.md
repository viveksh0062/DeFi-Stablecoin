# 🪙 Decentralized Stablecoin (DSC)

A fully on-chain **decentralized stablecoin system** inspired by MakerDAO’s DAI, built in Solidity with Foundry.  
This project demonstrates how a stable, collateral-backed currency can be created, maintained, and tested with **invariants** and **fuzzing**.

---

## 📂 Project Structure

├── script
│ ├── DeployDSC.s.sol # Deployment script
│ └── HelperConfig.s.sol # Config helper for deployment
│
├── src
│ ├── DecentralizedStableCoin.sol # ERC20 Stablecoin implementation
│ ├── DSCEngine.sol # Core engine for collateral & stability logic
│ └── libraries/
│ └── OracleLib.sol # Price feed library with safety checks
│
├── test
│ ├── fuzz/
│ │ ├── continueOnRevert.t.sol # Fuzzing test (continue on revert)
│ │ ├── failOnRevert.t.sol # Fuzzing test (fail on revert)
│ │ ├── Handler.t.sol # Handler contract for fuzz/invariants
│ │ ├── Invariants.t.sol # Invariant testing
│ │ └── OpenInvariantsTest.t.sol # Open invariant checks
│ │
│ ├── mocks/
│ │ └── MockV3Aggregator.sol # Mock Chainlink price feed
│ │
│ └── unit/
│ └── DSCEngineTest.t.sol # Unit tests for DSCEngine
│
└── foundry.toml

---

## 🚀 Features

- ✅ **Collateral-Backed Stablecoin** – Users can deposit collateral to mint DSC.  
- 📉 **Price Feeds with Safety Checks** – Uses `OracleLib` to handle stale or invalid Chainlink feeds.  
- 🔒 **Invariant Testing** – Ensures system safety with fuzz & invariant tests (`Handler`, `Invariants`).  
- ⚡ **Foundry Powered** – Built & tested with [Foundry](https://book.getfoundry.sh/).  
- 🧪 **Unit + Fuzz Tests** – Covers deterministic unit tests and advanced fuzzing scenarios.  
- 🛠️ **Modular Design** – Engine, Stablecoin, and Oracles are separated for clarity & extensibility.  

---

## 🧑‍💻 Installation & Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/viveksh0062/DeFi-Stablecoin.git
   cd DeFi-StableCoin
Install dependencies:

bash
Copy
Edit
forge install
Build & test:

bash
Copy
Edit
forge build
forge test
Run coverage:

bash
Copy
Edit
forge coverage
🧪 Testing Strategy
This repo uses unit tests, fuzzing, and invariants to ensure system safety:

Unit Tests (/test/unit) – Check core logic of the DSC Engine.

Fuzz Tests (/test/fuzz) – Randomized input testing to detect unexpected behavior.

Invariant Tests (/test/fuzz/Invariants.t.sol) – Guarantee critical properties always hold.

🔗 Connect with Me
🐦 Twitter/X: @viveksh0062

💼 LinkedIn: Vivek Sharma

⭐ Acknowledgements
Inspired by MakerDAO DAI and learning resources from Patrick Collins / Cyfrin.

Built as part of my journey into Web3 Security & Smart Contract Development.
