## BemToken & ERC20StakingPool Project

**Overview:**
This project consists of a suite of smart contracts designed for the BemToken ecosystem, focusing on ERC20 token functionalities including dynamic emission, token vesting, and a staking pool for rewarding ERC20 stakers with ERC20 tokens periodically and continuously. The core contracts in this project are BemToken, which implements an ERC20 token with additional features such as dynamic emission and airdrops, and ERC20StakingPool, a modern, gas-optimized staking contract for rewarding token stakers.

## Features:

**BemToken Contract:** Implements an ERC20 token with functionalities like initial minting, monthly token burn, external transfers, and claimable airdrops using Merkle Proofs.

**Dynamic Emission:** Adjusts the token emission rate based on external inputs or predefined logic to ensure flexible token supply management.

**Token Vesting:** Allows setting up vesting schedules for tokens to be distributed over a predefined period, enhancing token distribution security and predictability.

**ERC20 Staking Pool:** Enables token holders to stake their tokens to earn rewards over time, with features to stake, withdraw, and claim rewards seamlessly.








## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**



## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```
### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
