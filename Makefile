-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_KEY := fbf992b0e25ad29c85aae3d69fcb7f09240dd2588ecee449a4934b9e499102cc

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install Cyfrin/foundry-devops@0.0.11 --no-commit --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url https://eth-sepolia.g.alchemy.com/v2/fWr3m1Bq4Mqxz0n-WoE86aq24VsXTsrq --private-key $(DEFAULT_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(ALCHEMY_RPC_URL) --private-key $(METAMASK_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployBemToken.s.sol:DeployBemToken $(NETWORK_ARGS)
	@forge script script/DeployBemPresale.s.sol:DeployBemPresale $(NETWORK_ARGS)
	@forge script script/DeployBemVesting.s.sol:DeployBemVesting $(NETWORK_ARGS)
	@forge script script/DeployBemStaking.s.sol:DeployBemStaking $(NETWORK_ARGS)

# cast abi-encode "constructor(uint256)" 1000000000000000000000000 -> 0x00000000000000000000000000000000000000000000d3c21bcecceda1000000
# Update with your contract address, constructor arguments and anything else
verify:
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version 0.8.21+commit.d9974bed 0x54CDf5787f7b5B585687Fe83cD1A460fe5b94c7f src/Bem.sol:BemToken
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args 0x0000000000000000000000000000000000000000000000008ac7230489e800000000000000000000000000000000000000000000000000000001c6bf52634000000000000000000000000000000000000000000000000000001ff973cafa800000000000000000000000000054cdf5787f7b5b585687fe83cd1a460fe5b94c7f3a66ce04bfa0fac12c5b24f150c3b7b16f81a7ddae4778862490612445a7c5ae --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version 0.8.21+commit.d9974bed 0x3c6e05e4b54e50dB38BaEF70888FF8576Ff1851f src/BemPresale.sol:BemPresale
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args 0x00000000000000000000000054cdf5787f7b5b585687fe83cd1a460fe5b94c7f876ae3d088f6a906995a595a1fafcded051dc6ab0aad53df87e9c8543b7a32ee --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version 0.8.21+commit.d9974bed 0x2892d963544c49e390F9348E127ebFf70ddaC172 src/BemTokenVesting.sol:PresaleTokenVesting
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args 0x00000000000000000000000054cdf5787f7b5b585687fe83cd1a460fe5b94c7f000000000000000000000000e6f3889c8ebb361fa914ee78fa4e55b1bbed3a96 --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version 0.8.21+commit.d9974bed 0xfBFaB143F1109433a2Cd96f7B68Eb85a0b01Ef21 src/BemStaking.sol:BemStaking


#https://sepolia.etherscan.io/address/0x63ab7157810af3386491b4efbff79bed0aae41da