// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../ContractUtility.sol";
import "../../../BaseContract.sol";

/**
 * @title MutualFundContract
 * @dev The base contract for mutual details.fund contract
 */
contract MutualFundContract {
    using SafeMath for uint256;

    struct fundDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.Fund fund;
        uint256 cummulativeYieldValue;
        bool isFundCollected;
        bool isFundReturned;
    }

    struct fundInput {
        BaseContract _base; 
        string _fundName; 
        string _fundDescription; 
        address payable _fundManager; 
        address payable _fundHolder; 
        address _walletFundManager; 
        address _walletFundHolder; 
        uint256 _fundValue; 
        uint256 _fundShare; 
        uint256 _yieldRate; 
        uint256 _interestInterval; 
        uint256 _commisionRate; 
        uint256 _firstInterestDate; 
        ContractUtility.DisputeType _dispute;
    }
    
    fundDetails details;
    
    event BuyFund(uint256 _value);
    event TransferFund(address _transferee);
    event CollectFund(uint256 _value);
    event PayYield(uint256 _value);
    event RedeemInterest(uint256 _value);
    event ReturnFund(uint256 _value);
    event UpdateYieldRate(uint256 _value);
    event UpdateCommisionRate(uint256 _value);
    event EndFundContract(uint256 _value);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    modifier fundHolderOnly() {
        require(msg.sender == details.fund.fundHolder, "Only fund holder can call this function!");
        _;
    }

    modifier fundManagerOnly() {
        require(msg.sender == details.fund.fundManager, "Only fund manager can call this function!");
        _;
    }

    modifier isActive() {
        require(details.fund.state == ContractUtility.SecuritiesState.ACTIVE, "Fund should be active!");
        _;
    }

    constructor(fundInput memory input) {
    
        details.fund = ContractUtility.Fund(
            input._fundName,
            input._fundDescription,
            input._fundManager,
            input._fundHolder,
            ContractUtility.SecuritiesState.ISSUED,
            input._fundValue,
            input._fundShare,
            input._yieldRate,
            input._interestInterval,
            input._commisionRate,
            input._firstInterestDate
        );

        details.base = input._base;
        details.cummulativeYieldValue = 0;
        details.isFundCollected = false;
        details.isFundReturned = false;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.FUND,
            input._dispute, 
            input._fundManager, 
            input._fundHolder, 
            input._walletFundManager, 
            input._walletFundHolder
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // buy the fund
    function buy() external payable contractReady fundHolderOnly {
        require(details.fund.state == ContractUtility.SecuritiesState.ISSUED, "Fund should be issuing!");
        require(msg.value == details.fund.fundValue.mul(details.fund.fundShares), "Insufficient fund value!");

        details.fund.state = ContractUtility.SecuritiesState.ACTIVE;

        emit BuyFund(msg.value);
    }

    // sell the fund
    function transfer(address payable _transferee) public contractReady fundHolderOnly isActive {

        details.fund.fundHolder = _transferee;
        emit TransferFund(_transferee);
    }

    // collect the fund
    function collectFund() public contractReady fundManagerOnly isActive {
        require(!details.isFundCollected, "Fund has been collected!");

        details.fund.fundManager.transfer(details.fund.fundValue.mul(details.fund.fundShares));
        details.isFundCollected = true;

        emit CollectFund(details.fund.fundValue.mul(details.fund.fundShares));
    }

    // pay interest to the fund holders
    function payYield() external payable contractReady fundManagerOnly isActive {
        require(block.timestamp >= details.fund.interestPaymentDate, "Interest payment date has not reached!");
        require(msg.value == details.fund.fundValue.mul(details.fund.fundShares).mul(details.fund.yieldRate).mul(100 - details.fund.commisionRate).div(10000), 
            "Insufficient interest payment!");
    
        details.fund.interestPaymentDate = details.fund.interestPaymentDate.add(details.fund.interestInterval);
        details.cummulativeYieldValue = details.cummulativeYieldValue.add(msg.value);

        emit PayYield(msg.value);
    }

    // redeem the interest
    function redeemInterest() public contractReady fundHolderOnly isActive {
        require(details.cummulativeYieldValue > 0, "No interest to redeem!");
        require(address(this).balance >= details.cummulativeYieldValue.add(details.fund.fundValue.mul(details.fund.fundShares)),
            "Insufficient details.fund value!");

        details.fund.fundHolder.transfer(details.cummulativeYieldValue);
        details.cummulativeYieldValue = 0;

        emit RedeemInterest(details.cummulativeYieldValue);
    }

    // return the fund
    function returnFund() external payable contractReady fundManagerOnly isActive {
        require(msg.value == details.fund.fundValue.mul(details.fund.fundShares), "Insufficient fund value!");
        require(!details.isFundReturned, "Fund has been returned!");
        
        details.isFundReturned = true;

        emit ReturnFund(msg.value);
    }

    // update the yield rate
    function updateYieldRate(uint256 _newYieldRate) public contractReady fundManagerOnly {

        details.fund.yieldRate = _newYieldRate;

        emit UpdateYieldRate(_newYieldRate);
    }

    // update the commision rate
    function updateCommisionRate(uint256 _newCommisionRate) public contractReady fundManagerOnly {
        require(_newCommisionRate <= 50, "Commision rate should be less than 50!");

        details.fund.commisionRate = _newCommisionRate;

        emit UpdateCommisionRate(_newCommisionRate);
    }

    // complete the contract
    function endFundContract() public contractReady {
        require(msg.sender == details.fund.fundHolder, "Only fund holder can terminate the fund contract!");
        require(address(this).balance >= details.fund.fundValue.mul(details.fund.fundShares), "Insufficient fund value!");
        require(details.cummulativeYieldValue == 0, "Please redeem the interest first!");
        require(details.isFundReturned, "Please wait for the return of fund first!");

        details.fund.fundHolder.transfer(details.fund.fundValue.mul(details.fund.fundShares));
        details.fund.state = ContractUtility.SecuritiesState.REDEEMED;
        details.base.completeContract(details.contractId);
        emit EndFundContract(details.fund.fundValue.mul(details.fund.fundShares));
    }
}