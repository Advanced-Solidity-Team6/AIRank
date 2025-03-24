# AIRank

This is the decentralized platform for ranking AI models.

## Setup

This is a [foundry](https://book.getfoundry.sh/) project.

```bash
forge install
```

```bash
forge test
```

## Pyth Oracle

For the Pyth oracle, we use the [Pyth Network](https://pyth.network/) to get the price of the Ether.

Pyth smart contract address on the Filecoin testnet: `0xA2aa501b19aff244D90cc15a4Cf739D2725B5729`.
Price feed id for the ETH/USD: `0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace`.

## Resources

- <https://drand.love/blog/2025/03/04/onchain-sealed-bid-auction/>
- <https://github.com/randa-mu/blocklock-solidity>
