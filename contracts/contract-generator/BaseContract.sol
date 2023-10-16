// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../DeTrustToken.sol";
import "../TrustScore.sol";
import "./ContractUtility.sol";
import "../DisputeMechanism.sol";
import "./CommonContract.sol";

/**
 * @title BaseContract
 * @dev This contract is used for contracts logging and providing common functions after contract 
        creation.
 *
 * It allows to keep track of contract history, signing, verification, and chat communication.
 */
contract BaseContract {
    using SafeMath for uint256;

    // basic properties that are shared among all contracts
    struct BasicProperties {
        uint256 id;
        ContractUtility.ContractState state;
        uint256 creationTime;
        ContractUtility.ContractType contractType;
        ContractUtility.DisputeType disputeType;
        DisputeMechanism disputeMechanism;
        address payer;
        bytes32 _ad1;
        address payee;
        bytes32 _ad2;
        uint8 isSigned; // 0: not signed, 1: signed by one party, 2: signed by both parties
        ContractUtility.VerificationState isVerified;
        uint8 verifierNeeded;
        uint256 legitAmount;
        uint256 fraudAmount;
    }

    TrustScore trustScore; // add trust score instance for updating trust score

    uint256 counter = 0;
    uint256 minimumTimeFrame = 1 days;
    uint256 verificationCutOffTime = 2 days;

    constructor(TrustScore _trustScore) {
        trustScore = _trustScore;
    }

    mapping(address => uint256) public addressToIdRepo;
    mapping(uint256 => address) public idToAddressRepo;
    mapping(uint256 => BasicProperties) public generalRepo;
    mapping(uint256 => address[]) contractVerifyList;
    mapping(uint256 => address[]) contractFraudList;
    mapping(address => address) walletMapping;
    mapping(uint256 => string[]) messageLog;

    event ContractLogged(address indexed _contract, uint256 indexed _contractId);
    event ContractSigned(uint256 indexed _contractId, address indexed _signer);
    event ContractVerified(uint256 indexed _contractId, address indexed _verifier);
    event VerificationResolved(uint256 indexed _contractId, ContractUtility.VerificationState _vstate);
    event MessageSent(uint256 indexed _contractId, address indexed _sender);

    // modifier to check if the sender is involved in the contract
    modifier onlyInvolved(uint256 _contractId) {
        require(msg.sender == generalRepo[_contractId].payer ||
            msg.sender == generalRepo[_contractId].payee ||
            msg.sender == idToAddressRepo[_contractId], 
            "You are not involved in this contract!");
        _;
    }

    // modifier to check if correct price is paid on contract creation
    modifier correctInitPrice(address _payee) {
        TrustScore.TrustTier tier = trustScore.getTrustTier(_payee);

        require(msg.value == ContractUtility.getContractCost(tier) / 2, 
            "Incorrect price paid!");
        _;
    }

    // modifier to check if correct price is paid on contract payment
    modifier correctContractPayment(uint256 _contractId) {
        TrustScore.TrustTier tier = trustScore.getTrustTier(msg.sender);

        if (generalRepo[_contractId].payee == msg.sender) {
            require(msg.value == ContractUtility.getContractCost(tier) / 2, 
            "Incorrect price paid!");
        } else {
            require(msg.value == ContractUtility.getContractCost(tier), 
            "Incorrect price paid!");
        }
        _;
    }

    // contract history functions

    // add contract to repo
    function addToContractRepo(address _contractAddress, ContractUtility.ContractType _contractType, 
        ContractUtility.DisputeType _dispute, address _payee, address _payer, address _walletPayee, 
        address _walletPayer) public payable correctInitPrice(_payee) returns (uint256) {

        counter.add(1);

        // map cotract address to contract id
        addressToIdRepo[_contractAddress] = counter;
        idToAddressRepo[counter] = _contractAddress;

        walletMapping[_payee] = _walletPayee;
        walletMapping[_payer] = _walletPayer;

        // create a relative instance of basic properties for the contract and store it in repo
        generalRepo[counter] = BasicProperties(
            counter,
            ContractUtility.ContractState.DRAFT,
            block.timestamp,
            _contractType, 
            _dispute,
            DisputeMechanism(address(0)),
            _payer,
            bytes32(0),
            _payee,
            bytes32(0),
            0,
            ContractUtility.VerificationState.PENDING,
            20,// getVerifierTotal(Account.getTier(payer), Account.getTier(payee))
            0,
            0
        );

        emit ContractLogged(_contractAddress, counter);

        // return contract id to the respective contract
        return counter;
    }

    // proceed a contract
    function proceedContract(uint256 _contractId) public onlyInvolved(_contractId) {
        generalRepo[_contractId].state = ContractUtility.ContractState.INPROGRESS;
    }

    // complete a contract
    function completeContract(uint256 _contractId) public onlyInvolved(_contractId) {
        generalRepo[_contractId].state = ContractUtility.ContractState.COMPLETED;

        trustScore.increaseTrustScore(generalRepo[_contractId].payer, 
            ContractUtility.getContractCompletionReward(
                trustScore.getTrustTier(generalRepo[_contractId].payer)));

        trustScore.increaseTrustScore(generalRepo[_contractId].payee, 
            ContractUtility.getContractCompletionReward(
                trustScore.getTrustTier(generalRepo[_contractId].payee)));
    }

    // void a contract
    function voidContract(uint256 _contractId) public onlyInvolved(_contractId) {
        generalRepo[_contractId].state = ContractUtility.ContractState.VOIDED;
    }

    // dispute a contract
    function disputeContract(uint256 _contractId) public onlyInvolved(_contractId) {
        generalRepo[_contractId].state = ContractUtility.ContractState.DISPUTED;
    }

    // check if a contract is ready
    function isContractReady(uint256 _contractId) public view returns (bool) {
        return generalRepo[_contractId].state == ContractUtility.ContractState.INPROGRESS;
    }

    // contract signing functions

    // check if the contract is signed by both parties
    modifier isSigned(uint256 _contractId) {
        require(generalRepo[_contractId].isSigned == 2, "Contract is not signed by both parties!");
        _;
    }

    // get message hash for signing
    function getMessageHash(address _signer, uint256 _contractId, uint _nonce, 
        uint8 _v, bytes calldata _r, bytes calldata  _s) public pure returns (bytes32) {
        
        return keccak256(abi.encodePacked(_signer, 
            keccak256(abi.encodePacked(_contractId,
            keccak256(abi.encodePacked('VERIFY')), 
            keccak256(abi.encodePacked(_v, _r, _s)), _nonce))));
    }

    // sign the contract with message hash
    function sign(uint256 _contractId, uint _nonce, uint8 _v, bytes calldata _r, bytes calldata _s) 
        public payable onlyInvolved(_contractId) correctContractPayment(_contractId) {

        bytes32 messageHash = getMessageHash(msg.sender, _contractId, _nonce, _v, _r, _s);

        if (msg.sender == generalRepo[_contractId].payer) {
            require(generalRepo[_contractId]._ad1 == bytes32(0), 
                "You have already signed this contract!");
            generalRepo[_contractId]._ad1 = messageHash;

        } else {
            require(generalRepo[_contractId]._ad2 == bytes32(0), 
                "You have already signed this contract!");
            generalRepo[_contractId]._ad2 = messageHash;
        }

        generalRepo[_contractId].isSigned = generalRepo[_contractId].isSigned + 1;

        emit ContractSigned(_contractId, msg.sender);
    }

    // verify the signature of the contract
    // need to be verify if there is a dispute only
    function verifySignature(address _signer, uint256 _contractId, uint _nonce, 
        uint8 _v, bytes calldata _r, bytes calldata _s) public view returns (bool) {

        bytes32 messageHash = getMessageHash(_signer, _contractId, _nonce, _v, _r, _s);

        if (_signer == generalRepo[_contractId].payer) {
            return generalRepo[_contractId]._ad1 == messageHash;
        } else {
            return generalRepo[_contractId]._ad2 == messageHash;
        }

    }

    // verification functions

    /**
     * @dev Modifier to check if the verification time limit is passed.
     * @param _contractId The contract id to be verified.
     * 
     * Requirements:
        * The contract must be not verified.
        * The contract could be verified if the minimun verification time limit has not passed.
        * The contract could be verified if the minimun verification time limit has passed 
          and the verifier amount is not exceeded 
          and the maximum verification time limit has not passed.
     */
    modifier verifyAllowed(uint256 _contractId, ContractUtility.VerificationState _vstate) {
        require(_vstate == ContractUtility.VerificationState.PENDING, "Contract is already verified!");

        require(block.timestamp - generalRepo[_contractId].creationTime <= verificationCutOffTime, 
            "Verification time is over!");

        require(block.timestamp - generalRepo[_contractId].creationTime <= minimumTimeFrame ||
            (block.timestamp - generalRepo[_contractId].creationTime > minimumTimeFrame && 
                generalRepo[_contractId].legitAmount.add(generalRepo[_contractId].fraudAmount) < 
                generalRepo[_contractId].verifierNeeded), 
            "Verifier amount exceeded!");

        _;
    }

    /**
     * @dev Modifier to check if the verification could be resolved.
     * @param _contractId The contract id to be verified.
     * 
     * Requirements:
        * The contract must be not verified.
        * The contract could be verified if the minimun verification time limit has passed
          and the verifier amount is reached or exceeded.
        * The contract could be verified if the maximum verification time limit has passed.
     */
    modifier verificationCanBeResolved(uint256 _contractId) {
        require(generalRepo[_contractId].isVerified == ContractUtility.VerificationState.PENDING, 
            "Contract is already verified!");

        require(block.timestamp - generalRepo[_contractId].creationTime > verificationCutOffTime ||
            (block.timestamp - generalRepo[_contractId].creationTime > minimumTimeFrame &&
            (generalRepo[_contractId].legitAmount.add(generalRepo[_contractId].fraudAmount) >= 
                generalRepo[_contractId].verifierNeeded)), 
            "Verification is not availble yet!");
        _;
    }

    // verifier should not be involved in the contract
    modifier notInvolved(uint256 _contractId) {
        require(msg.sender != generalRepo[_contractId].payer && 
            msg.sender != generalRepo[_contractId].payee, 
            "You are involved in this contract!");

        if (generalRepo[_contractId].contractType == ContractUtility.ContractType.COMMON) {
            CommonContract common = CommonContract(idToAddressRepo[_contractId]);
            require(!common.isPayer(msg.sender) && !common.isPayee(msg.sender), 
                "You are involved in this contract!");
        }
        _;
    }

    // get the number of verifiers needed for the contract
    function getVerifierTotal(TrustScore.TrustTier _payerTier, TrustScore.TrustTier _payeeTier) 
        internal pure returns (uint8) {
        return ContractUtility.getVerifierAmount(_payerTier) + 
            (ContractUtility.getVerifierAmount(_payeeTier));
    }

    // verify the contract
    // contract can be verified by any address except involvers
    function verifyContract(uint256 _contractId, ContractUtility.VerificationState _vstate, 
        address _wallet) public isSigned(_contractId) verifyAllowed(_contractId, _vstate) 
        notInvolved(_contractId) returns (ContractUtility.VerificationState) {

        walletMapping[msg.sender] == _wallet;
        
        if(_vstate == ContractUtility.VerificationState.LEGITIMATE) {
            contractVerifyList[_contractId].push(msg.sender);
            generalRepo[_contractId].legitAmount = generalRepo[_contractId].legitAmount.add(1);
        } else {
            contractFraudList[_contractId].push(msg.sender);
            generalRepo[_contractId].fraudAmount = generalRepo[_contractId].fraudAmount.add(1);
        }

        emit ContractVerified(_contractId, msg.sender);

        if (generalRepo[_contractId].legitAmount >= generalRepo[_contractId].verifierNeeded / 2) {
            generalRepo[_contractId].isVerified = ContractUtility.VerificationState.LEGITIMATE;
            return ContractUtility.VerificationState.LEGITIMATE;

        } else if (generalRepo[_contractId].fraudAmount >= generalRepo[_contractId].verifierNeeded / 2) {
            generalRepo[_contractId].isVerified = ContractUtility.VerificationState.FRAUDULENT;
            return ContractUtility.VerificationState.FRAUDULENT;
        }
        return ContractUtility.VerificationState.PENDING;
    }

    /**
     * @dev Resolve the verification of the contract.
     * @param _contractId The contract id to be verified.
     *
     * Requirements:
        * The true verifier will be rewarded with 10 DTRs.
        * The false verifier will be deducted with 5 DTRs and 1 trust score.
        * FRAUDULENT:
            * The payer and the payee will be deducted with 500 DTRs and 2 trust scores.
     */
    function resolveVerification(uint256 _contractId) public verificationCanBeResolved(_contractId) isSigned(_contractId) {

        if (generalRepo[_contractId].isVerified == ContractUtility.VerificationState.PENDING) {
            if (generalRepo[_contractId].legitAmount >= generalRepo[_contractId].fraudAmount) {
                generalRepo[_contractId].isVerified = ContractUtility.VerificationState.LEGITIMATE;
            } else {
                generalRepo[_contractId].isVerified = ContractUtility.VerificationState.FRAUDULENT;
            }
        }

        if (generalRepo[_contractId].isVerified == ContractUtility.VerificationState.LEGITIMATE) {
            proceedContract(_contractId);
            for (uint256 i = 0; i < contractVerifyList[_contractId].length; i++) {
                DeTrustToken(walletMapping[contractVerifyList[_contractId][i]]).mint(10);
            }

            for (uint256 i = 0; i < contractFraudList[_contractId].length; i++) {
                DeTrustToken(walletMapping[contractFraudList[_contractId][i]]).burn(5);
                trustScore.decreaseTrustScore(contractFraudList[_contractId][i], 1);
            }
            
        } else {
            voidContract(_contractId);
            
            DeTrustToken(walletMapping[generalRepo[_contractId].payer]).burn(500);
            DeTrustToken(walletMapping[generalRepo[_contractId].payee]).burn(500);
            trustScore.decreaseTrustScore(generalRepo[_contractId].payer, 2);
            trustScore.decreaseTrustScore(generalRepo[_contractId].payee, 2);
            

            for (uint256 i = 0; i < contractFraudList[_contractId].length; i++) {
                DeTrustToken(walletMapping[contractFraudList[_contractId][i]]).mint(10);
            }

            for (uint256 i = 0; i < contractVerifyList[_contractId].length; i++) {
                DeTrustToken(walletMapping[contractVerifyList[_contractId][i]]).burn(5);
                trustScore.decreaseTrustScore(contractVerifyList[_contractId][i], 1);
            }
        }

        emit VerificationResolved(_contractId, generalRepo[_contractId].isVerified);
    }

    // chat communication functions

    // involvers (initiator and respondent in the case of common contract) can send message to each other
    function sendMessage(uint256 _contractId, string memory _message) public onlyInvolved(_contractId) {
        
        // label each message string with the sender
        if (msg.sender == generalRepo[_contractId].payer) {
            messageLog[_contractId].push(string(abi.encodePacked('Payer', ': ', _message)));
        } else {
            messageLog[_contractId].push(string(abi.encodePacked('Payee', ': ', _message)));
        }

        emit MessageSent(_contractId, msg.sender);
        
    }

    // get all messages in the message log for a certain contract by invlovers only
    function retriveMessage(uint256 _contractId) public view onlyInvolved(_contractId) returns (string memory) {
        string memory messages = "";

        // concatenate all messages in the message log
        for (uint i = 0; i < messageLog[_contractId].length; i++) {
            messages = string(abi.encodePacked(messages, messageLog[_contractId][i], '\n'));
        }

        return messages;
    }

}