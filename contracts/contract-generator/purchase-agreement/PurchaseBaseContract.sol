// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../ContractUtility.sol";
import "../BaseContract.sol";

/**
 * @title PurchaseBaseContract
 * @dev The base contract for purchase contract 
 */
contract PurchaseBaseContract {
    using SafeMath for uint256;

    struct purchaseDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.Purchase purchase;
        bool isReceived;
        bool isPaid;
        bool isDelivered;
        bool isWithdrawn;
    }

    struct purchaseInput {
        BaseContract _base;
        address payable _seller; 
        address payable _buyer;
        address _walletSeller;
        address _walletBuyer; 
        string _description; 
        uint256 _price; 
        uint256 _paymentDate;
        uint256 _deliveryDate; 
        ContractUtility.DisputeType _dispute;
    }

    purchaseDetails details;
    
    event Paid(address _buyer, address _seller, uint256 _value);
    event Withdrawn(address _buyer, address _seller, uint256 _value);
    event Delivered(address _seller, address _buyer);
    event Received(address _seller, address _buyer);
    event Terminated(address _buyer, address _seller, uint256 _value);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    modifier sellerOnly() {
        require(msg.sender == details.purchase.seller, "You are not the seller!");
        _;
    }

    modifier buyerOnly() {
        require(msg.sender == details.purchase.buyer, "You are not the buyer!");
        _;
    }

    modifier checkPaymentDate() {
        require(details.purchase.paymentDate <= block.timestamp, "Payment date has not reached!");
        _;
    }

    constructor(purchaseInput memory input) {
        
        details.purchase = ContractUtility.Purchase(
            input._seller,
            input._buyer,
            input._description,
            input._price,
            input._paymentDate,
            input._deliveryDate
        );

        details.base = input._base;
        details.isReceived = false;
        details.isPaid = false;
        details.isDelivered = false;
        details.isWithdrawn = false;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.PURCHASE,
            input._dispute, 
            input._seller, 
            input._buyer, 
            input._walletSeller, 
            input._walletBuyer
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // pay the seller
    function pay() external payable contractReady buyerOnly checkPaymentDate {
        require(msg.value == details.purchase.price, "Payment amount is incorrect!");
        require(!details.isPaid, "Payment has been made!");

        details.isPaid = true;

        emit Paid(details.purchase.buyer, details.purchase.seller, details.purchase.price);
    }

    // withdraw the payment
    function withdraw() public contractReady sellerOnly checkPaymentDate {
        require(details.isPaid, "Payment has not been made!");
        require(details.isReceived, "Product has not been received!");
        require(address(this).balance >= details.purchase.price, "Incorrect amount!");
        
        payable(details.purchase.seller).transfer(details.purchase.price);
        details.isWithdrawn = true;

        emit Withdrawn(details.purchase.buyer, details.purchase.seller, details.purchase.price);
    }

    // the seller delivers the product
    function deliverProduct() public contractReady buyerOnly {

        details.isDelivered = true;

        emit Delivered(details.purchase.seller, details.purchase.buyer);
    }

    // the buyer receives the product
    function receiveProduct() public contractReady buyerOnly {
        require(details.isDelivered, "Product has not been delivered!");

        details.isReceived = true;

        emit Received(details.purchase.seller, details.purchase.buyer);
    }

    // terminate the contract, when transaction is not completed
    function terminate() public contractReady {
        require(msg.sender == details.purchase.buyer || msg.sender == details.purchase.seller, 
            "You are not involved in this contract!");

        if (details.isPaid && !details.isDelivered) {
            require((block.timestamp >= details.purchase.deliveryDate && !details.isDelivered) || 
                (block.timestamp >= details.purchase.paymentDate && !details.isPaid), "Delivery date has not reached!");

            details.base.voidContract(details.contractId);
        
            details.purchase.buyer.transfer(details.purchase.price);
        } else if (details.isPaid && details.isDelivered) {
            require(details.isWithdrawn, "Payment has not been withdrawn!");

        } else {
            details.base.completeContract(details.contractId);

        }

        emit Terminated(details.purchase.buyer, details.purchase.seller, details.purchase.price);
    }
}