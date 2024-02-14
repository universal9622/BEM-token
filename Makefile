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
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version 0.8.21+commit.d9974bed 0xAf59dB7E4C9DB20eFFDE853B56412cfF1dc3f379 src/Bem.sol:BemToken
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args 0x0000000000000000000000000000000000000000000000008ac7230489e800000000000000000000000000000000000000000000000000000001c6bf52634000000000000000000000000000000000000000000000000000001ff973cafa8000000000000000000000000000af59db7e4c9db20effde853b56412cff1dc3f3793a66ce04bfa0fac12c5b24f150c3b7b16f81a7ddae4778862490612445a7c5ae --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version 0.8.21+commit.d9974bed 0x07C88116a4c89D4E8Afea7d567fD0c7c0F798F2C src/BemPresale.sol:BemPresale
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args 0x000000000000000000000000af59db7e4c9db20effde853b56412cff1dc3f379876ae3d088f6a906995a595a1fafcded051dc6ab0aad53df87e9c8543b7a32ee --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version 0.8.21+commit.d9974bed 0x83B7ff28224270D4869339f9E7Cca9b5379BeE92 src/BemTokenVesting.sol:PresaleTokenVesting
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args 0x000000000000000000000000af59db7e4c9db20effde853b56412cff1dc3f379000000000000000000000000e6f3889c8ebb361fa914ee78fa4e55b1bbed3a96 --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version 0.8.21+commit.d9974bed 0x862CB78e752Ea75Cd044067f5e0bbE1f5d03f570 src/BemStaking.sol:BemStaking


#https://sepolia.etherscan.io/address/0x63ab7157810af3386491b4efbff79bed0aae41da