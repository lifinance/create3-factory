# CREATE3 Factory

Factory contract for easily deploying contracts to the same address on multiple chains, using CREATE3.

This was forked from https://github.com/zeframlou/create3-factory

The deploy script was updated to use legacy (non EIP-1559) transactions due to the fact that some chains that LIFI supports do not support EIP-1559.

## Why?

Deploying a contract to multiple chains with the same address is annoying. One usually would create a new Ethereum account, seed it with enough tokens to pay for gas on every chain, and then deploy the contract naively. This relies on the fact that the new account's nonce is synced on all the chains, therefore resulting in the same contract address.
However, deployment is often a complex process that involves several transactions (e.g. for initialization), which means it's easy for nonces to fall out of sync and make it forever impossible to deploy the contract at the desired address.

One could use a `CREATE2` factory that deterministically deploys contracts to an address that's unrelated to the deployer's nonce, but the address is still related to the hash of the contract's creation code. This means if you wanted to use different constructor parameters on different chains, the deployed contracts will have different addresses.

A `CREATE3` factory offers the best solution: the address of the deployed contract is determined by only the deployer address and the salt. This makes it far easier to deploy contracts to multiple chains at the same addresses.

LIFI Supports a large number of chains and we are only growing. CREATE3 allows us to manage our deployments better as well as make integration by developers more painless.

## Deployments

`CREATE3Factory` has been deployed to `0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1` on the following networks:

### Mainnets

- Ethereum
- Polygon
- Binance Smart Chain
- Gnosis
- Fantom
- OKXChain
- Avalanche C-Chain
- Arbitrum
- Optimism
- Moonriver
- Moonbeam
- CELO
- FUSE
- CRONOS
- Velas
- Harmony Shard 0
- EVMOS
- Aurora
- Boba

### Testnets

- Goerli
- Sepolia

## Usage

Call `CREATE3Factory::deploy()` to deploy a contract and `CREATE3Factory::getDeployed()` to predict the deployment address, it's as simple as it gets.

A few notes:

- The salt provided is hashed together with the deployer address (i.e. msg.sender) to form the final salt, such that each deployer has its own namespace of deployed addresses.
- The deployed contract should be aware that `msg.sender` in the constructor will be the temporary proxy contract used by `CREATE3` rather than the deployer, so common patterns like `Ownable` should be modified to accomodate for this.

## Installation

To install with [Foundry](https://github.com/foundry-rs/foundry):

```
forge install lifinance/create3-factory
```

## Local development

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework.

### Dependencies

```bash
forge install
```

### Compilation

```bash
forge build
```

### Deployment

Make sure that the network is defined in foundry.toml, then run:

```bash
./deploy/deploy.sh [network]
```
