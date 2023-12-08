// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../ContractUtility.sol";
import "../../../BaseContract.sol";

contract FutureContract {
    using SafeMath for uint256;

    struct futureDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.Future future;
        uint256 currentAmount;
        bool isPaid;
        bool isReceived;
    }

    struct futureInput {
        BaseContract _base; 
        address payable _seller; 
        address payable _buyer;
        address _walletSeller; 
        address _walletBuyer; 
        string _assetType; 
        uint256 _assetCode; 
        uint256 _quantity; 
        uint256 _deliveryDays; 
        uint256 _futurePrice; 
        string _description; 
        ContractUtility.DisputeType _dispute;
    }

    futureDetails details;

    event ContractInit();
    event IncreaseBalance(uint256 value);
    event Settle();
    event VerifyReceive();
    event RevertFuture();

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    modifier sellerOnly() {
        require(msg.sender == details.future.seller, "You are not the seller!");
        _;
    }

    modifier buyerOnly() {
        require(msg.sender == details.future.buyer, "You are not the buyer!");
        _;
    }

    modifier isActive() {
        require(details.future.state == ContractUtility.DerivativeState.ACTIVE, "Future contract is not active!");
        _;
    }

    modifier deliveryDatePassed() {
        require(block.timestamp >= details.future.deliveryDate, "Delivery date has not reached!");
        details.future.state = ContractUtility.DerivativeState.EXPIRED;
        _;
    }

    constructor(futureInput memory input) {

        details.future = ContractUtility.Future(
            input._seller,
            input._buyer, 
            ContractUtility.DerivativeState.PENDING,
            input._assetType, 
            input._assetCode,
            input._quantity, 
            block.timestamp.add(input._deliveryDays.mul(1 days)), 
            input._futurePrice, 
            input._futurePrice.div(2), 
            input._description);

        details.base = input._base;
        details.currentAmount = 0;
        details.isPaid = false;
        details.isReceived = false;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.FUTURE,
            input._dispute, 
            input._seller, 
            input._buyer, 
            input._walletSeller, 
            input._walletBuyer
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // buyer verify the future contract
    function buyerInit() external payable contractReady buyerOnly {
        require(details.future.state == ContractUtility.DerivativeState.PENDING, "Future contract has been verified!");
        require(msg.value >= details.future.margin.mul(details.future.quantity), "Future premium is not correct!");

        details.future.state = ContractUtility.DerivativeState.ACTIVE;
        details.currentAmount = details.currentAmount.add(msg.value);
        
        emit ContractInit();
    }
    
    // add balance to contract
    function increaseBalance() external payable contractReady buyerOnly isActive {
        require(details.currentAmount.add(msg.value) <= details.future.futurePrice.mul(details.future.quantity), "Payment exceeds limit");

        details.currentAmount = details.currentAmount.add(msg.value);

        emit IncreaseBalance(msg.value);
    }

    // pay the seller
    function settle() public contractReady buyerOnly isActive deliveryDatePassed {
        require(details.currentAmount == details.future.futurePrice.mul(details.future.quantity), "Payment is not correct!");

        details.future.seller.transfer(details.future.futurePrice.mul(details.future.quantity));
        details.isPaid = true;
        details.currentAmount = 0;

        emit Settle();
    }

    // buyer verify receiving the asset
    function verifyReceive() public contractReady buyerOnly isActive deliveryDatePassed {
        require(details.isPaid, "Payment has not been made!");

        details.isReceived = true;
        details.base.completeContract(details.contractId);
        emit VerifyReceive();
    }

    // revert the future contract
    function revertFuture() internal isActive {
        require(msg.sender == details.future.seller || msg.sender == details.future.buyer, "You are not involved in this contract!");
        require(address(this).balance >= details.currentAmount, "Balance is not enough to revert!");
        require(block.timestamp < details.future.deliveryDate, "Delivery date has passed!");

        details.future.buyer.transfer(details.currentAmount);
        details.base.voidContract(details.contractId);
        emit RevertFuture();
    }

}