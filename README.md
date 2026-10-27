# Food Traceability DApp

**Module:** Distributed Digital Transactions – CA1
**College:** CCT College Dublin
**Student:** Andre Luiz Oliveira da Cunha - 2024214

## Overview

A blockchain-based decentralized application (DApp) for tracking food products across the supply chain, from farm to retailer. Each product batch is recorded on-chain, and every transfer between two parties (sender → receiver) is stored as an immutable, verifiable transaction. This gives all participants and consumers a transparent and tamper-proof history of the product's origin, handling and condition.

## Supply Chain Actors

- **Farmer** – creates a new product batch
- **Processor** – receives and processes the batch
- **Distributor** – transports the batch and records checkpoints (e.g. temperature, location)
- **Retailer** – receives the final product for sale
- **Consumer** – verifies the full history of a batch

## Tech Stack

| Tool             | Purpose                                                |
| ---------------- | ------------------------------------------------------ |
| Solidity         | Smart contract development                             |
| Remix IDE        | Writing, compiling, deploying and testing the contract |
| Ganache          | Local Ethereum blockchain for development              |
| Python (web3.py) | Deploying and interacting with the contract            |
| Shell script     | Automating the local environment and scripts           |

## Project Structure

```
contracts/          Solidity smart contract (FoodTrace.sol)
scripts/            Python deploy/interaction scripts and shell script
docs/diagrams/      UML diagrams (use case, sequence, class)
docs/screenshots/   Screenshots of contract testing
poster/             PowerPoint poster presentation
```

## How to Run

TODO