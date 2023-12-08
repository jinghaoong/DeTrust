# DeTrust

DeTrust is a visionary blockchain-based platform that reimagines the way we create,
execute, and enforce digital contracts. Rooted in the principles of decentralisation,
transparency, and community consensus, DeTrust empowers users to interact with
confidence, assured that their agreements are backed by a robust and impartial
framework.

## Contracts Implementation

### Main Contracts
`Accounts.sol` - user management

`DeTrustToken.sol` - token management, token used for contract creation

`TrustScore.sol` - a measure to reflect a user's reliability

`BaseContract.sol` - central repo to track created contract

`Dispute.sol` - current v1, dispute generator 

`CommunicationChannel.sol` - for contract specific communication

`SigningMechanism.sol` - sign contract and validate signature

`VotingMechanism.sol` - govern contract verification logic

`CommonContract.sol` - common contract template

### Side Contracts
Contracts other than stated in the `Main Contracts` session are extensions for current iteration, future work needed.

Various contract templates.

Available for next iteration service enhancement.

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
EVM enviroment : REMIX-SHANGHAI 

Demonstrating a smooth and success operation here (briefly).

With test addresses:
1. 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
2. 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
3. 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
4. 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
5. 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
6. 0x17F6AD8Ef982297579C203069C1DbfFE4348c372
7. 0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678
8. 0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7
9. 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C
10. 0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC

**NOTE**:
> Please comment the following code in `VotingMechanism` for manual testing.
> ```
> modifier verificationCanBeResolved(uint256 _contractId) {
>    /*
>    ContractUtility.BasicProperties memory properties = base.getGeneralRepo(_contractId);
>
>   require(properties.isVerified == ContractUtility.VerificationState.PENDING, 
>        "Contract is not available for verification!");
>
>    require(block.timestamp - properties.verificationStart > verificationCutOffTime ||
>        (block.timestamp - properties.verificationStart > minimumTimeFrame &&
>        (properties.legitAmount >= properties.verifierNeeded / 2)), 
>        "Resolve is not available yet!");
>    */
>    _;
>}
>```

### Initialization
We set address 1 (0x5B38Da6a701c568545dCfcB03FcB875f56beddC4) as our universal owner address.

Execute the steps below using address 1.
1. Deploy `Accounts.sol`.

1. Deploy `TrustScore.sol`.
   Parameters: 250

1. Deploy `DeTrustToken.sol`.
   Parameters: 100000000000000000

1. Deploy `BaseContract.sol`.
   Parameters: [TrustScoreAddress, DeTrustTokenAddress]
   
1. Deploy `CommunicationChannel.sol`.
   Parameters: BaseContractAddress

1. Deploy `SigningMechanism.sol`.
   Parameters: BaseContractAddress

1. Deploy `VotingMechanism.sol`.
   Parameters: [BaseContractAddress, DeTrustTokenAddress, TrustScoreAddress]

1. `approveAddress` in TrustScore.
    1. BaseContractAddress
    2. VotingMechanismAddress

1. `setApproval` in DeTrustToken.
   1. BaseContractAddress
   2. VotingMechanismAddress
   
1. `setApproval` in BaseContract.
   1. CommunicationChannelAddress
   2. SigningMechanismAddress
   3. VotingMechanismAddress

1. `setTrustScore` in TrustScore. 
   - OPTIONAL: Default trust score is 250.
   
1. `mintFor` in DeTrustToken.
   - OPTIONAL: Some functions (createContract) need initial wealth.

### Common Contract Creation
Common Contract is the default contract. The other contracts can be generated using the same procedure.

1. `approve` the BaseContractAddress(also used as Wallet Mapping) with the exact contract creation costs for both initiator and responder respectively.

1. Deploy `CommonContract.sol` by the chosen initiator.
   Parameters: 
    [baseContractAddress, [respondent+payers], 
    [initiator+payees], initiator_wallet, respondent_wallet,
    "title", "type", [obligations], [descriptions], [payment_amounts], obligations_count, dispute_type(0 or 1)];

### Contract Execution

1. `sign` in `SigningMechanism`
   - Involvers only.
   Parameters:
   [contractId, nonce(uint), _v(uint8), _r(bytes), _s(bytes)]

1. `verifyContract` in `VotingMechanism`.
   - Involvers should not execute this function.
   Parameters:
   [contractId, (1 for `LEGITIMATE` 2 for `FRAUDULENT`), sender_wallet]

1. `resolveVerification` in `VotingMechanism`.
   
1. `resolveObligation` by Payers and `verifyObligationDone` by Payees.
   - The payments are done in ETH, with unit Wei.

1. `initiatorWithdraw` in `CommonContract`.

1. `endContract` in `CommonContract` and `completeContract` in `BaseContract`.
   
### Alternative: Dispute a contract

1. Deploy `Dispute.sol`.
   Parameters:
   [CommonContractAddress, TrustScoreAddress, RespondentAddress, title, description]

1. `disputeContract` in BaseContract.

### Alternative: Communication

`sendMessage` and `retrieveMessage` in CommunicationChannel.
`sendMessage` and `retrieveMessage` in CommunicationChannel.
