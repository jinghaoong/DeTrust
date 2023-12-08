// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../DeTrustToken.sol";
import "../TrustScore.sol";
import "./ContractUtility.sol";
import "../dispute-resolution-v1/Dispute.sol";
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

    address payable owner;
    TrustScore trustScore; // add trust score instance for updating trust score
    DeTrustToken deTrustToken;
    address voting;

    uint256 counter = 0;

    mapping(address => uint256) public addressToIdRepo;
    mapping(uint256 => address) public idToAddressRepo;
    mapping(uint256 => ContractUtility.BasicProperties) public generalRepo;
    mapping(uint256 => Dispute) disputeRepo;
    mapping(address => uint256) approved;
    mapping(address => address) walletMapping;
    
    event ContractLogged(address _contract, uint256 _contractId);
    event ContractProceeded(uint256 _cotractId);
    event ContractCompleted(uint256 _contractId);
    event ContractPendingComplete(uint256 _contractId);
    event ContractVoided(uint256 _contractId);
    event ContractDisputeRecorded(uint256 _contractId);
    event SetApprovalToBase(address _approvedAddress);
    event SetVotingMechanism(address _votingContract);
    event PropertiesRecorded(uint256 _contractId);
    event WalletSet(address _user);
    event BaseOwnerWithdrawn();

    constructor(TrustScore _trustScore, DeTrustToken _deTrustToken) {
        owner = payable(address(msg.sender));
        approved[owner] = 1;
        trustScore = _trustScore;
        deTrustToken = _deTrustToken;
    }

    modifier ownerOnly() {
        require(msg.sender == owner, "You are not the owner!");
        _;
    }

    modifier approvedOnly() {
        require(approved[msg.sender] == 1, "You are not approved to execute this function!");
        _;
    }

    modifier approvedOrInvolved(uint256 _contractId) {
        require(approved[msg.sender] == 1 || isInvolved(_contractId, msg.sender), "You are not authorized to execute this function!");
        _;
    }

    modifier notFreeze(uint256 _contractId) {
        require(generalRepo[_contractId].state != ContractUtility.ContractState.DISPUTED &&
            generalRepo[_contractId].state != ContractUtility.ContractState.COMPLETED &&
            generalRepo[_contractId].state != ContractUtility.ContractState.VOIDED, "Contract is inactivated!");
        _;
    }

    function isActive(uint256 _contractId) public view returns (bool) {
        bool active = generalRepo[_contractId].state != ContractUtility.ContractState.DISPUTED &&
            generalRepo[_contractId].state != ContractUtility.ContractState.COMPLETED &&
            generalRepo[_contractId].state != ContractUtility.ContractState.VOIDED;
        return active;
    }

    // modifier to check if correct price is paid on contract payment
    modifier creationEligibility(address _payee, address _payer, address _walletPayee, 
        address _walletPayer) {
        uint256 amountPayee = trustScore.getContractCost(trustScore.getTrustTier(_payee));
        uint256 amountPayer = trustScore.getContractCost(trustScore.getTrustTier(_payer));

        require(trustScore.getTrustScore(_payee) >= 2, "Insufficient trust score for initiator!");
        require(trustScore.getTrustScore(_payer) >= 2, "Insufficient trust score for respondent!");
        require(deTrustToken.balanceOf(_walletPayee) >= amountPayee, "Insufficient trust token for initiator!");
        require(deTrustToken.balanceOf(_walletPayer) >= amountPayer, "Insufficient trust token for respondent!");
        
        deTrustToken.transferFrom(_walletPayee, address(this), amountPayee);
        deTrustToken.transferFrom(_walletPayer, address(this), amountPayer);

        {
        uint256 currentAllowance = deTrustToken.allowance(address(this), voting);
        currentAllowance = currentAllowance.add((amountPayee.add(amountPayer)).mul(4));
        deTrustToken.approve(voting, currentAllowance);
        }
        _;
    }

    // modifier to check if the sender is involved in the contract
    modifier onlyInvolved(uint256 _contractId, address _sender) {
        require(_sender == generalRepo[_contractId].signature.payer ||
            _sender == generalRepo[_contractId].signature.payee ||
            _sender == idToAddressRepo[_contractId], 
            "You are not involved in this contract!");
        _;
    }

    function isInvolved(uint256 _contractId, address _sender) public view returns (bool) {
        bool involved = _sender == generalRepo[_contractId].signature.payer ||
            _sender == generalRepo[_contractId].signature.payee ||
            _sender == idToAddressRepo[_contractId];

        return involved;
    }

    // contract history functions
    // add contract to repo
    function addToContractRepo(ContractUtility.ContractRepoInput memory repoInput) public 
        creationEligibility(repoInput._payee, repoInput._payer, repoInput._walletPayee, repoInput._walletPayer) 
        returns (uint256) {
        
        counter = counter.add(1);

        // map cotract address to contract id
        addressToIdRepo[repoInput._contractAddress] = counter;
        idToAddressRepo[counter] = repoInput._contractAddress;

        walletMapping[repoInput._payee] = repoInput._walletPayee;
        walletMapping[repoInput._payer] = repoInput._walletPayer;

        
        ContractUtility.Signature memory signature = ContractUtility.Signature(
            repoInput._payer,
            bytes32(0),
            repoInput._payee,
            bytes32(0),
            0
        );
        
        // create a relative instance of basic properties for the contract and store it in repo
        generalRepo[counter] = ContractUtility.BasicProperties(
            counter,
            ContractUtility.ContractState.DRAFT,
            block.timestamp,
            repoInput._contractType, 
            repoInput._dispute,
            signature,
            ContractUtility.VerificationState.PENDING,
            trustScore.getVerifierAmount(trustScore.getTrustTier(repoInput._payer)) 
                + trustScore.getVerifierAmount(trustScore.getTrustTier(repoInput._payee)),
            0,
            0,
            false,
            0
        );
        
        emit ContractLogged(repoInput._contractAddress, counter);

        // return contract id to the respective contract
        return counter;
    }

    // proceed a contract
    function proceedContract(uint256 _contractId) public approvedOrInvolved(_contractId) notFreeze(_contractId) {
        require(generalRepo[_contractId].isVerified == ContractUtility.VerificationState.LEGITIMATE, 
            "The contract is not verified!");
        generalRepo[_contractId].state = ContractUtility.ContractState.INPROGRESS;

        emit ContractProceeded(_contractId);
    }

    // complete a contract
    function completeContract(uint256 _contractId) public approvedOrInvolved(_contractId) {
        if (generalRepo[_contractId].completed) {
            generalRepo[_contractId].state = ContractUtility.ContractState.COMPLETED;

            trustScore.increaseTrustScore(generalRepo[_contractId].signature.payer, 
                trustScore.getContractCompletionReward(
                    trustScore.getTrustTier(generalRepo[_contractId].signature.payer)));

            trustScore.increaseTrustScore(generalRepo[_contractId].signature.payee, 
                trustScore.getContractCompletionReward(
                    trustScore.getTrustTier(generalRepo[_contractId].signature.payee)));
            emit ContractCompleted(_contractId);

        } else {
            generalRepo[_contractId].completed = true;
            emit ContractPendingComplete(_contractId);
        }
        
    }

    // void a contract
    function voidContract(uint256 _contractId) public approvedOrInvolved(_contractId) {
        generalRepo[_contractId].state = ContractUtility.ContractState.VOIDED;
        emit ContractVoided(_contractId);
    }

    // dispute a contract
    function disputeContract(uint256 _contractId, Dispute disputeAddress, 
        ContractUtility.DisputeType disputeType) public onlyInvolved(_contractId, msg.sender) {
        generalRepo[_contractId].state = ContractUtility.ContractState.DISPUTED;
        generalRepo[_contractId].disputeType = disputeType;
        disputeRepo[_contractId] = disputeAddress;
        emit ContractDisputeRecorded(_contractId);
    }

    // check if a contract is ready
    function isContractReady(uint256 _contractId) public view returns (bool) {
        return generalRepo[_contractId].state == ContractUtility.ContractState.INPROGRESS;
    }

    // check if the contract is signed by both parties
    function isSigned(uint256 _contractId) public view returns (bool) {
        require(generalRepo[_contractId].signature.isSigned == 2, "Contract is not signed by both parties!");
        return true;
    }

    function setApproval(address _approvedAddress) public ownerOnly {
        approved[_approvedAddress] = 1;
        emit SetApprovalToBase(_approvedAddress);
    }

    function setVotingAccess(address _votingContract) public ownerOnly {
        approved[_votingContract] = 1;
        voting = _votingContract;
        emit SetVotingMechanism(_votingContract);
    }

    function setGeneralRepo(uint256 _contractId, ContractUtility.BasicProperties memory _newProp) public approvedOnly {
        generalRepo[_contractId] = _newProp;
        emit PropertiesRecorded(_contractId);
    }

    function setWalletMapping(address _user, address _wallet) public approvedOnly {
        walletMapping[_user] = _wallet;
        emit WalletSet(_user);
    }

    function getGeneralRepo(uint256 _contractId) public view approvedOrInvolved(_contractId) returns(ContractUtility.BasicProperties memory) {
        return generalRepo[_contractId];
    }

    function getAddressRepo(uint256 _contractId) public view returns(address) {
        return idToAddressRepo[_contractId];
    }

    function getIdRepo(address _contractAddress) public view returns(uint256) {
        return addressToIdRepo[_contractAddress];
    }

    function getWalletAddress(address _user) public view approvedOnly returns (address) {
        return walletMapping[_user];
    }

    function getDisputeContract(uint256 _contractId) public view 
        approvedOrInvolved(_contractId) returns (address) {
        return address(disputeRepo[_contractId]);
    }

    function ownerWithdraw() external ownerOnly {
        owner.transfer(address(this).balance);
        emit BaseOwnerWithdrawn();
    }

}
