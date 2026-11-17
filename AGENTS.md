# create3-factory

LI.FI's fork of [zeframlou/create3-factory](https://github.com/zeframlou/create3-factory): a `CREATE3Factory`
contract that deploys contracts to the same address on every EVM chain. The address depends only on the
deployer (`msg.sender`) and the salt, not on the creation code. The factory itself is deployed with legacy
(non EIP-1559) transactions because some supported chains lack EIP-1559.

## Ownership

API Expansion squad, reviewer Daniela (`@melianessa`). Review channel: `#dev-sc-review`.

## Layout

| Path | What lives there |
| --- | --- |
| `src/CREATE3Factory.sol` | The factory: `deploy(salt, creationCode)` and `getDeployed(deployer, salt)` |
| `src/ICREATE3Factory.sol` | Its interface |
| `src/CREATE3Factory.flattened` | Flattened source of the factory (handy for manual explorer verification) |
| `script/Deploy.s.sol` | Forge script that deploys the factory with `PRIVATE_KEY` |
| `deploy/deploy.sh` | Wrapper around the script: reads `.env`, deploys, writes the address to `deployments/<network>.json` |
| `deployments/` | One JSON per network with the deployed `CREATE3Factory` address (the deployment record) |
| `lib/` | Git submodules: `forge-std`, `solmate` |
| `foundry.toml` | Compiler settings (solc 0.8.28, cancun, 30 optimizer runs), RPC endpoints and explorer keys per network |

## Commands

Foundry only (CI pins v1.9.0 in `.github/workflows/test.yml`); there is no package.json or Makefile.

```bash
git submodule update --init --recursive   # or: forge install
forge build --sizes
forge test -vvv                            # the repo has no test/ folder today, so this runs zero tests
./deploy/deploy.sh <network>               # network must be a key under [rpc_endpoints] in foundry.toml
```

CI (`test.yml`) runs build and test on `workflow_dispatch` only, not on pull requests.

## Config and env

- Copy `.env.example` to `.env` (gitignored). `deploy/deploy.sh` sources it.
- `PRIVATE_KEY` is the deployer key. The factory is deployed with plain `CREATE`, so its address depends on
  the deployer and its nonce: the shared LI.FI address needs deployer `0x11F11121DF7256C40339393b0FB045321022ce44`
  at nonce 0 on the target chain. Check the nonce and `deployments/` before deploying or retrying; any earlier
  transaction from that account gives a different factory address.
- `RPC_URL_<NETWORK>` (upper case network name) and the explorer key per network are read through
  `foundry.toml`. `.env.example` lists only some of them; add the ones for the network you deploy to.

## Conventions

- Adding a chain: add `[rpc_endpoints]` (and `[etherscan]` if verifiable) entries in `foundry.toml`, deploy,
  commit the new `deployments/<network>.json`. Never edit an existing address by hand.
- Contracts deployed through the factory see the temporary CREATE3 proxy as `msg.sender` in their
  constructor, so `Ownable`-style constructors must take the owner as an argument.
- Verification inside `deploy.sh` is disabled; verify manually (for example with the flattened source).

## Deeper docs

- [README.md](README.md): why CREATE3, usage notes.
