// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../ContractUtility.sol";
import "../BaseContract.sol";

/**
 * @title SimplePaymentContract
 * @dev The base contract for simple payment contract
 */
contract SimplePaymentContract {

    struct paymentDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.SimplePayment simplePayment;
        bool isPaid;
        bool isWithdrawn;
    }

    struct paymentInput {
        BaseContract _base;
        address payable _payer; 
        address payable _payee; 
        address _walletPayer; 
        address _walletPayee; 
        uint256 _amount; 
        string _description; 
        ContractUtility.DisputeType _dispute;
    }
    
    paymentDetails details;

    event PaymentMade(address _payer, address _payee, uint256 _amount);
    event PaymentWithdrawn(address _payer, address _payee, uint256 _amount);
    event ContractTerminated(address _payer, address _payee, uint256 _amount);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    constructor(paymentInput memory input) {
        details.simplePayment = ContractUtility.SimplePayment(
            input._payer,
            input._payee,
            input._amount,
            block.timestamp,
            input._description
        );

        details.base = input._base;
        details.isPaid = false;
        details.isWithdrawn = false;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.SIMPLE_PAYMENT,
            input._dispute, 
            input._payee, 
            input._payer, 
            input._walletPayee, 
            input._walletPayer
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // pay the payee
    function pay() external payable contractReady {
        require(msg.sender == details.simplePayment.payer, "You are not the payer!");
        require(!details.isPaid, "Payment has been made!");
        require(msg.value == details.simplePayment.amount, "Incorrect amount!");

        details.simplePayment.paymentDate = block.timestamp;
        details.isPaid = true;

        emit PaymentMade(details.simplePayment.payer, details.simplePayment.payee, details.simplePayment.amount);
    }

    // withdraw the payment
    function withdraw() public contractReady {
        require(msg.sender == details.simplePayment.payee, "You are not the payee!");
        require(details.isPaid, "Payment has not been made!");
        require(address(this).balance >= details.simplePayment.amount, "Incorrect amount!");

        details.simplePayment.payee.transfer(details.simplePayment.amount);
        details.isWithdrawn = true;

        emit PaymentWithdrawn(details.simplePayment.payer, details.simplePayment.payee, details.simplePayment.amount);
    }

    // terminate the contract
    function terminate() public contractReady {
        require(msg.sender == details.simplePayment.payer || msg.sender == details.simplePayment.payee, 
            "You are not involved in this contract!");

        if (details.isPaid && !details.isWithdrawn) {
            require(address(this).balance >= details.simplePayment.amount, "Incorrect contract balance!");
            details.simplePayment.payer.transfer(details.simplePayment.amount);
            details.base.voidContract(details.contractId);

        } else if (details.isPaid) {
            require(details.isWithdrawn, "Payment has not been withdrawn!");
            details.base.completeContract(details.contractId);
        } else {
            details.base.voidContract(details.contractId);
        }

        emit ContractTerminated(details.simplePayment.payer, details.simplePayment.payee, details.simplePayment.amount);
    }
}