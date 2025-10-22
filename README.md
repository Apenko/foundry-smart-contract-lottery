# 🎰 Foundry Smart Contract Lottery (Raffle System)

A **fully decentralized lottery (raffle)** built using **Solidity** and **Foundry**, powered by **Chainlink VRF v2.5** for provably fair randomness.  
This project automates raffle entry, winner selection, and payout using **smart contracts**, **VRF randomness**, and **automated upkeep cycles**.

---

## 🧠 Overview

This project demonstrates a production-grade **decentralized lottery system** implemented with:
- **Foundry (Forge + Cast + Anvil)**
- **Chainlink VRF v2.5**
- **Mock LINK token integration**
- **Advanced test-driven development (TDD)**
- **Fully automated deployment and funding scripts**

---

## ⚙️ Tech Stack

| Category | Tools / Frameworks |
|-----------|--------------------|
| Smart Contract | Solidity (v0.8.19) |
| Framework | Foundry (Forge, Cast, Anvil) |
| Oracle | Chainlink VRF v2.5 |
| Testing | Forge-std, Mocks, Fuzz, Integration Tests |
| Utilities | Solmate (ERC20), Makefile Automation |
| Deployment | Foundry Scripts, Makefile, Sepolia Testnet |

---

## 📂 Project Structure

foundry-smart-contract-lottery/
│
├── src/
│ └── Raffle.sol
│
├── script/
│ ├── DeployRaffle.s.sol
│ ├── HelperConfig.s.sol
│ └── Interactions.s.sol
│
├── test/
│ ├── RaffleTest.t.sol
│ └── InteractionsTest.t.sol
│
├── lib/
│ ├── forge-std/
│ ├── chainlink-brownie-contracts/
│ └── solmate/
│
├── Makefile
├── foundry.toml
└── README.md

yaml
Copy code

---

## 🚀 Features

✅ **Provably Fair Randomness** — Uses Chainlink VRF v2.5  
✅ **Automated Upkeep System** — Time-based raffle cycles  
✅ **Mock VRF + LINK** for local testing  
✅ **Unit, Integration, and Fuzz Testing** with Forge  
✅ **Makefile Automation** for deployment & configuration  
✅ **Environment-Agnostic Deployment** (Anvil + Sepolia)  
✅ **Full Lifecycle Tests** — from entry → upkeep → winner → payout  

---

## 🧱 Contracts

### `Raffle.sol`
- Manages player entries and payments  
- Triggers Chainlink VRF requests  
- Selects and pays a random winner  
- Resets for next round automatically  

### `HelperConfig.s.sol`
- Stores network-specific configurations  
- Provides dynamic setup for VRF, LINK, and subscription IDs  

### `DeployRaffle.s.sol`
- Automates contract deployment across networks  
- Works with both local mocks and testnets  

### `Interactions.s.sol`
- Handles **VRF Subscription Creation**, **Funding**, and **Consumer Addition**  

---

## 🧪 Testing

### Run All Tests
```bash
make test
Run with Detailed Logs
forge test -vvvv
Run Integration Tests Only
forge test --match-contract InteractionsTest -vvvv
```

### All tests include:
Player entry validation
VRF request & fulfillment simulation
Winner payout and raffle reset checks
Event emission & revert condition testing
Fuzz and lifecycle consistency verification

### 🧰 Development Commands
Start Local Anvil Node
make anvil
Deploy Locally
make deploy
Deploy to Sepolia
make deploy ARGS="--network sepolia"
Chainlink VRF Subscription Commands
make createSubscription
make fundSubscription
make addConsumer

## 🧾 Configuration
```bash
.env Example
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
PRIVATE_KEY=your-private-key
ETHERSCAN_API_KEY=your-etherscan-api-key
```

### foundry.toml
```bash
Defines remappings and build settings:
toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
  '@chainlink/contracts/=lib/chainlink-brownie-contracts/contracts/',
  '@solmate=lib/solmate/src/'
]
```

### 🧠 Key Learnings
Building VRF-based smart contracts using Foundry.
Managing on-chain randomness and automated upkeep cycles.
Structuring Foundry projects with scripts, mocks, and Makefiles.
Implementing fuzz, event, and integration testing.
Creating reusable Foundry templates for Chainlink-based dApps.

#### 💡 Future Improvements
Add front-end integration (Next.js + Wagmi + RainbowKit)
Implement Chainlink Automation for live upkeep
Enable multi-winner and reward-tier logic
Add Chainlink Automation tests on Sepolia

#### 🧑‍💻 Author
Ezenwanne Ikechukwu Solomon (Apenko)
📧 ezenwanneikechukwu2@gmail.com
🌐 linkedin.com/in/ikechukwu-ezenwanne-880a80345
🐦 @Apenko2
💻 github.com/Apenko

### 🪙 License
This project is licensed under the MIT License.

### ⭐ If you like this project, give it a star on GitHub!