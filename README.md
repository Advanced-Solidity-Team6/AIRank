# AIRank

This is the decentralized platform for ranking AI models.

<div align="center" style="display: flex;">
    <img src="assets/AIRank.png" width="500" />
</div>

The sequence diagram of the process implemented in this DApp:

<div align="center" style="display: flex;">
    <img src="assets/AIRankSequence.png" width="500" />
</div>

## Setup

This is a [foundry](https://book.getfoundry.sh/) project.

```bash
forge install
```

```bash
npm install
```

```bash
forge test
```

## Blocklock Contract

The deployed BlocklockSender Proxy Contract on the Filecoin testnet: `0xfF66908E1d7d23ff62791505b2eC120128918F44`.

## Price Oracle

For the price oracle, we use the [Pyth Network](https://pyth.network/) to get the price of the Ether.

Pyth smart contract address on the Filecoin testnet: `0xA2aa501b19aff244D90cc15a4Cf739D2725B5729`.

Price feed id for the ETH/USD: `0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace`.

## Resources

- <https://drand.love/blog/2025/03/04/onchain-sealed-bid-auction/>
- <https://github.com/randa-mu/blocklock-solidity>
