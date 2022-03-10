# SDC Project

## Description
This little project aims to implement SDC settlement logic in a very lean way focussing solely on a integrative solidity based implementation as much as possible.
In the first version the project contains four contracts.

## Getting Started
Sample Unit Testing in solidity will be provided soon.
Simple Tests as minting EUR Tokens and Inception of an SDC as well as inception of single SDC Trades to come.

## Contract Structure
Two implementations are available:
* A more native ERC20 implementation containing three contracts: SDC, Ledger, Valuation Oracle
* A ERC1155 implementation where entire functionality is contained in one contract

## Getting started with Visual Studio and Hardhat:
A good getting started can be found [here](https://blog.oliverjumpertz.dev/how-to-set-up-a-solidity-project-and-create-your-first-smart-contract)
We provide the essential steps in the following, assuming NodeJS 14.x LTS ist installed.

1. Check out project
2. Go to folder and initalise a new npm project: `npm init -y`. A basic `package.json` file should occur
3. Install Hardhat as local solidity dev environment: `npx hardhat`
4. Select: Create an empty hardhat.config.js and change solidity compiler version to 0.8.4
5. Install Hardhat as a development dependency: `npm install --save-dev hardhat`
6. Install further testing dependencies:
`npm install --save-dev @nomiclabs/hardhat-waffle @nomiclabs/hardhat-ethers ethereum-waffle chai  ethers solidity-coverage`
7. add plugins to hardhat.config.ts: 
```
require("@nomiclabs/hardhat-waffle"); 
require('solidity-coverage');
```
8. Adding commands to `package.json`:
``` 
"scripts": {
    "build": "hardhat compile",
    "test:light": "hardhat test",
    "test": "hardhat coverage"
  },
```
9. run `npm run build`
10. run `npm run test`

## Javascript based testing libraries for solidity
- `ethereum-waffle`: Waffle is a Solidity testing library. It allows you to write tests for your contracts with JavaScript.
- `chai`: Chai is an assertion library and provides functions like expect.
- `ethers`: This is a popular Ethereum client library. It allows you to interface with blockchains that implement the Ethereum API.
- `solidity-coverage`: This library gives you coverage reports on unit tests with the help of Istanbul.

