// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../ContractUtility.sol";
import "../BaseContract.sol";

/**
 * @title ServiceBaseContract
 * @dev The base contract for service contract
 * 
 * This contract is used for service contracts, include subscription and services.
 */
contract ServiceBaseContract {
    using SafeMath for uint256;
    
    struct serviceDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.Service service;
        uint256 cummulativePaymentCount;
        uint256 creationDate;
    }

    struct serviceInput {
        BaseContract _base;
        ContractUtility.ServiceType _serviceType;
        address payable _serviceProvider;
        address payable _client;
        address _walletPayee; 
        address _walletPayer;
        uint256 _contractDuration;
        string _description;
        uint256 _paymentTerm;
        uint256 _singlePayment;
        uint256 _firstPaymentDate;
        ContractUtility.DisputeType _dispute;
    }
    
    serviceDetails details;

    event Paid(address _client, address _serviceProvider, uint256 _value);
    event Withdrawn(address _client, address _serviceProvider, uint256 _value);
    event ContractTerminated(address _client, address _serviceProvider);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    constructor(serviceInput memory input) {
        
        details.service = ContractUtility.Service(
            input._serviceType,
            input._serviceProvider,
            input._client,
            input._contractDuration.mul(1 days),
            input._description,
            input._paymentTerm.mul(1 days),
            input._singlePayment,
            input._firstPaymentDate
        );

        details.base = input._base;
        details.creationDate = block.timestamp;
        details.cummulativePaymentCount = 0;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.SERVICE,
            input._dispute, 
            input._client, 
            input._serviceProvider, 
            input._walletPayee, 
            input._walletPayer
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // pay the service provider
    function pay() external payable contractReady {
        require(details.creationDate + details.service.contractDuration > block.timestamp &&
            block.timestamp >= details.service.paymentDate, "Payment date has not reached!");
        require(msg.sender == details.service.client, "You are not the client!");
        require(msg.value == details.service.singlePayment, "Payment amount is incorrect!");

        details.service.paymentDate = details.service.paymentDate.add(details.service.paymentTerm);
        details.cummulativePaymentCount = details.cummulativePaymentCount.add(1);

        emit Paid(details.service.client, details.service.serviceProvider, details.service.singlePayment);
    }

    // withdraw the payment
    function withdraw() public contractReady {
        require(msg.sender == details.service.serviceProvider, "You are not the service provider!");
        require(address(this).balance >= details.service.singlePayment.mul(details.cummulativePaymentCount), "No payment to withdraw!");

        details.service.serviceProvider.transfer(details.service.singlePayment.mul(details.cummulativePaymentCount));
        details.cummulativePaymentCount = 0;

        emit Withdrawn(details.service.client, details.service.serviceProvider, 
            details.service.singlePayment.mul(details.cummulativePaymentCount));
    }

    // terminate the contract
    function terminate() public contractReady  {
        require(msg.sender == details.service.client || msg.sender == details.service.serviceProvider, 
            "You are not involved in this contract!");
        require(details.cummulativePaymentCount == 0, "Payment has not been withdraw!");

        details.base.completeContract(details.contractId);

        emit ContractTerminated(details.service.client, details.service.serviceProvider);
    }

}