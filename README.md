# DeTrust

DeTrust is a visionary blockchain-based platform that reimagines the way we create,
execute, and enforce digital contracts. Rooted in the principles of decentralisation,
transparency, and community consensus, DeTrust empowers users to interact with
confidence, assured that their agreements are backed by a robust and impartial
framework.

## Console Auto-Testing

Tool: Code editor / terminal with hardhat, solidity, typescript and javascript support.

1. Clone the repo to local.
2. Navigate to local repo location in terminal.
3. Execute the test using the following console commands.
   
   For deploy test:
   ```
   npm install
   npx hardhat run scripts/deploy.ts
   ```

   Expected console output: (addresses may be different):
   ```
   Deploying contracts with the account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
   Accounts deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
   TrustScore deployed to: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
   DeTrustToken deployed to: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
   ContractUtility deployed to: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
   BaseContract deployed to: 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
   VotingMechanism deployed to: 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
   SigningMechanism deployed to: 0x0165878A594ca255338adfa4d48449f69242Eb8F
   CommunicationChannel deployed to: 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
   Approvals set
   ```

   For contract unit / semi-integrated tests:
   ```
   npm install
   npx hardhat test
   ```
   To execute specific test file:
   
   npx hardhat test test/<test file name with extension\>
   ```
   npx hardhat test test/BaseContract.test.js
   ```

   Example console output: 

   ```
   Compiled 17 Solidity files successfully


    BaseContract
      ✔ Should be able to record a new contract (176ms)
      ✔ Should be able to proceed verified contract (121ms)
      ✔ Should be able to complete contract (245ms)
      ✔ Should be able to void contract (75ms)
      ✔ Should be able to record dispute on contract (78ms)
      ✔ Should be able to check if contract is inprogress
      ✔ Should be able to check if contract is signed
      ✔ Setter check (103ms)
      ✔ Getter check (50ms)
   ```

## Manual testing:

Tool: Remix IDE / Remix Web

### Initialization
