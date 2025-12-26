.DEFAULT_GOAL := help
.PHONY: help test build anvil deploy-local deploy-sepolia deploy-mainnet

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} \
		/^[a-zA-Z_-]+:.*##/ { \
			printf "\033[36m%-20s\033[0m %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)

test: ## Run tests
	forge test

build: ## Build contracts
	forge build

anvil: ## Start local anvil
	anvil

deploy-local: ## Deploy to local anvil
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url local \
		--broadcast -vvvv

deploy-sepolia: ## Deploy to Sepolia
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url sepolia \
		--broadcast \
		--verify -vvvv

deploy-mainnet: ## Deploy to Mainnet
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url mainnet \
		--broadcast \
		--verify -vvvv
