// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ContractUtility.sol";
import "./BaseContract.sol";

/**
 * @title CommonContract
 * @dev This contract is used for widely customisable contracts.
 *
 * It allows for the creation of contracts with multiple obligations.
 */
contract CommonContract {
    using SafeMath for uint256;

    struct commonDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.Common common;
        address payable initiator; // set to the first payee
        address payable respondent; // set to the first payer
        uint256 totalObligations; 
        bool[] obligationsDone; // set to true when obligation is done by payer
        bool[] obligationsVerified; // set to true when done obligation is verified by payee
    }

    struct commonInput {
        BaseContract _base;
        address payable[] _payers; 
        address payable[] _payees;
        address _walletInitiator; 
        address _walletRespondent; 
        string _title;
        string _contractType;
        string[] _obligationTitles; 
        string[] _obligationDescriptions;
        uint256[] _paymentAmounts; 
        uint256 _totalObligations; 
        ContractUtility.DisputeType _dispute;
    }
    
    commonDetails public details;
    address completeCheck;

    event ContractCreated(address indexed _contract, uint256 indexed _contractId);
    event ObligationDone(uint256 indexed _obligationId);
    event ObligationVerified(uint256 indexed _obligationId);
    event ContractEnded(address indexed _contract, uint256 indexed _contractId, address sender);
    event InitiatorWithdrawn(uint256 _totalBalance);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    modifier initiatorOnly() {
        require(msg.sender == details.initiator, "You are not the initiator!");
        _;
    }

    modifier contractCompleted() {
        (bool done, bool verified) = checkContractState();
        require(done, "Contract is not done yet!");
        require(verified, "Contract is not verified yet!");
        _;
    }
    
    constructor(commonInput memory input) {

        // check if all obligation arrays have the same length
        require(input._totalObligations == input._obligationTitles.length, 
            "Total obligations does not match obligation titles!");
        require(input._totalObligations == input._obligationDescriptions.length, 
            "Total obligations does not match obligation descriptions!");
        require(input._totalObligations == input._paymentAmounts.length, 
            "Total obligations does not match payment amounts!");

        details.base = input._base;
        details.initiator = input._payees[0];
        details.respondent = input._payers[0];
        details.totalObligations = input._totalObligations;
        details.obligationsDone = new bool[](details.totalObligations);
        details.obligationsVerified = new bool[](details.totalObligations);

        // create common contract instance
        details.common = ContractUtility.Common(
            input._title,
            input._contractType,
            details.initiator,
            details.respondent,
            input._obligationTitles,
            input._obligationDescriptions,
            input._paymentAmounts,
            input._payers,
            input._payees
        );

        // store contract in repo
        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.COMMON,
            input._dispute, 
            details.initiator, 
            details.respondent, 
            input._walletInitiator, 
            input._walletRespondent
        );

        details.contractId = details.base.addToContractRepo(repoInput);

        emit ContractCreated(address(this), details.contractId);
    }

    modifier active() {
        require(details.base.isActive(details.contractId), "Contract is inactivated!");
        _;
    }
    
    // verify if the function caller is one of the payer
    // accessible from other contract
    function isPayer(address caller) public view returns (bool) {
        for (uint256 i = 0; i < details.common.payer.length; i++) {
            if (caller == details.common.payer[i]) {
                return true;
            }
        }
        return false;
    }

    // verify if the function caller is one of the payee
    // accessible from other contract
    function isPayee(address caller) public view returns (bool) {
        for (uint256 i = 0; i < details.common.payee.length; i++) {
            if (caller == details.common.payee[i]) {
                return true;
            }
        }
        return false;
    }

    // resolve obligation with _obligationId by paying the correct amount
    // obligation is done by any payer
    function resolveObligation(uint256 _obligationId) public payable contractReady {
        require(isPayer(msg.sender), "You are not the payer!");
        require(!details.obligationsDone[_obligationId], "This obligation has been done!");
        require(msg.value == details.common.paymentAmount[_obligationId], 
            "You have not paid the correct amount!");
        
        details.obligationsDone[_obligationId] = true;

        emit ObligationDone(_obligationId);
    }

    // verify a done obligation with _obligationId by the payee
    // verification is done by any payee
    function verifyObligationDone(uint256 _obligationId) public contractReady {
        require(isPayee(msg.sender), "You are not the payee!");
        require(details.obligationsDone[_obligationId], "Obligation is not done yet!");
        
        details.obligationsVerified[_obligationId] = true;

        emit ObligationVerified(_obligationId);
    }

    // check if an obligation with _obligationId is done or verified
    function checkObligationState(uint256 _obligationId) public view returns (bool, bool) {
        return (details.obligationsDone[_obligationId], details.obligationsVerified[_obligationId]);
    }

    // check if all obligations are done and verified
    function checkContractState() public view returns (bool, bool) {
        uint256 done = 0;
        uint256 verified = 0;

        for (uint256 i = 0; i < details.totalObligations; i++) {
            if (details.obligationsDone[i]) {
                done = done.add(1);
            }
            if (details.obligationsVerified[i]) {
                verified = verified.add(1);
            }
        }
        
        return (done == details.totalObligations, verified == details.totalObligations);
    }

    function initiatorWithdraw() external initiatorOnly contractCompleted active {
        require(address(this).balance > 0, "No balance to withdraw!");
        uint256 totalBalance = address(this).balance;
        details.initiator.transfer(totalBalance);
        emit InitiatorWithdrawn(totalBalance);
    }

    // end contract and destruct the contract instance
    // contract is ended by any involved party
    // all the obligations should be done and verified before ending the contract
    function endContract() public contractCompleted active {
        require(msg.sender == details.initiator || msg.sender == details.respondent, 
            "You are not involved in this contract!");
        require(msg.sender != completeCheck, "You have completed this contract!");
        require(address(this).balance == 0, "Contract balance is not withdrawn yet!");

        completeCheck = msg.sender;
        details.base.completeContract(details.contractId);
        emit ContractEnded(address(this), details.contractId, msg.sender);
        
    }

}