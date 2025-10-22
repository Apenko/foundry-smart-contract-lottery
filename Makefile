# ============================================================
# 🧱 Foundry Project Makefile
# Automates building, testing, deploying, and managing contracts
# ============================================================

# Load environment variables (safe even if .env is missing)
-include .env

# ------------------------------------------------------------
# 📦 Common Configuration
# ------------------------------------------------------------
DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Default network args: local anvil
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# If deploying to Sepolia via ARGS="--network sepolia"
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# ------------------------------------------------------------
# 🧰 Phony Targets (commands)
# ------------------------------------------------------------
.PHONY: all clean remove install update build test snapshot format anvil \
        help deploy deploy-sepolia createSubscription addConsumer fundSubscription

# ------------------------------------------------------------
# 🆘 Help Menu
# ------------------------------------------------------------
help:
	@echo "=============================="
	@echo " Foundry Project - Command Guide"
	@echo "=============================="
	@echo ""
	@echo "Usage:"
	@echo "  make build                Compile contracts"
	@echo "  make test                 Run all tests"
	@echo "  make deploy               Deploy (local by default)"
	@echo "      ARGS=\"--network sepolia\"   Deploy to Sepolia"
	@echo "  make deploy-sepolia       Deploy using named Foundry account"
	@echo "  make anvil                Start local node"
	@echo "  make createSubscription   Create Chainlink VRF sub"
	@echo "  make addConsumer          Add contract as consumer"
	@echo "  make fundSubscription     Fund Chainlink sub"
	@echo "  make clean/remove/update/install/build/format"
	@echo ""
	@echo "Example:"
	@echo "  make deploy ARGS=\"--network sepolia\""
	@echo "  make deploy-sepolia"
	@echo ""

# ------------------------------------------------------------
# 🧹 Project Maintenance
# ------------------------------------------------------------
all: clean remove install update build

clean:; forge clean

remove:; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules" || true

install:; forge install cyfrin/foundry-devops@0.2.2 && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && forge install foundry-rs/forge-std@v1.8.2 && forge install transmissions11/solmate@v6

update:; forge update
build:; forge build
test:; forge test
snapshot:; forge snapshot
format:; forge fmt

# ------------------------------------------------------------
# ⚙️ Local Node (Anvil)
# ------------------------------------------------------------
anvil:; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# ------------------------------------------------------------
# 🚀 Deployment & Interaction
# ------------------------------------------------------------

# Default deploy (local or Sepolia based on ARGS)
deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

# Deploy using Foundry named account (configured in foundry.toml)
deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--account myaccount \
		--broadcast --verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

# Chainlink VRF interaction scripts
createSubscription:
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

addConsumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)

fundSubscription:
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)
