# Facthound

**Facthound is a truth-seeking missile.** 

**Facthound is information bounties and information markets.**

**Facthound is the only forum that matters.**

## Overview

Facthound is an information bounty system where users ask questions and post optional bounties held in the Facthound escrow smart contract. Bounty posters pay out rewards to users who provide their preferred answers. While platforms like Quora and Reddit may refuse certain types of questions, Facthound's incentive-based model ensures virtually any question can be answered for the right price.

## Key Features

- **Information Bounties**: Post questions with ETH rewards for quality answers
- **Blockchain Integration**: Secure escrow system using smart contracts
- **Dual Authentication**: Traditional username/password or Ethereum wallet (SIWE) authentication
- **Answer Selection**: Question askers can select the best answer to receive the bounty
- **On-chain Verification**: Confirm questions, answers, and selections on the blockchain

## How It Works

1. **Ask a Question**: Users post questions with optional ETH bounties held in escrow
2. **Submit Answers**: Other users provide answers to earn the bounty
3. **Select Answer**: The question asker selects their preferred answer
4. **Payout**: The bounty is automatically released to the selected answerer

## This Repo

This repository contains Facthound's smart contract. It can be deployed on any EVM blockchain, but I currently have it running on Base.
[Here](https://basescan.org/address/0x6f639b39606936f8dfb82322781c913170b66f4f) is the live contract.
This repo is set up to use [Foundry](https://github.com/foundry-rs/foundry). 

## Contract Details

The Facthound smart contract implements a decentralized information bounty system with the following key features:

### Core Functionality
- **Question Creation**: Users can create questions with ETH bounties (a small fee is taken per question)
- **Answer Submission**: Anyone can submit answers to open questions
- **Answer Selection**: Question askers can select winning answers to trigger bounty payouts
- **Cancellation**: Contract owner can cancel questions in exceptional cases

### Key Contract Functions

- `createQuestion(bytes32 questionHash)` - Create a new question with ETH bounty
- `createAnswer(bytes32 questionHash, bytes32 answerHash)` - Submit an answer to a question
- `selectAnswer(bytes32 questionHash, bytes32 answerHash)` - Select winning answer and trigger payout
- `cancelQuestion(bytes32 questionHash)` - Admin function to cancel a question (returns bounty to asker)

### State Management

Questions can be in one of three states:
- `OPEN` - Question is active and accepting answers
- `RESOLVED` - Question has a selected answer and bounty paid out
- `CANCELLED` - Question was cancelled by admin (bounty returned)

### Fee Structure

The contract charges a small fee on question creation, configurable at deployment:
- Fee percentage: `asker_fee_per_10000 / 10000` (e.g., 100 = 1% fee)
- Fees can be withdrawn by the contract owner

### Security Features

- Custom error messages for better debugging
- Strict access controls with ownership model
- State validation to prevent double payouts or unauthorized actions

## Setup and Installation

### Clone
```bash
git clone https://github.com/matthew-ritch/facthound-contracts
cd facthound-contracts
```

### Compile
```bash
forge compile
```

### Run Tests
```bash
forge test
```

### Environment Variables

Create a `.env` file with the following variables:
```
BASE_MAINNET_RPC=https://base-mainnet.g.alchemy.com/v2/your_alchemy_api_key
BASESCAN_API_KEY=your_basescan_api_key
WALLET_ADDRESS=your_deployer_wallet_address
WALLET_KEY=your_deployer_wallet_key
```

### Deploy Contract

```bash
source .env                             
forge script script/FactHound.s.sol:FactHoundScript --sig 'run()' --rpc-url $BASE_MAINNET_RPC --broadcast --verify -vvvv --legacy --etherscan-api-key $BASESCAN_API_KEY  
```
