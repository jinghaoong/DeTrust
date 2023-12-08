// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../ContractUtility.sol";
import "../BaseContract.sol";

/**
 * @title LeaseContract
 * @dev The base contract for lease contract 
 */
contract LeaseContract {
    using SafeMath for uint256;
    
    struct leaseDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.Lease lease;
        uint256 cummulativePaymentCount;
    }

    struct leaseInput {
        BaseContract _base;
        address payable _landlord; 
        address payable _tenant;
        address _walletLandlord; 
        address _walletTenant;
        string _description; 
        uint256 _startDate; 
        uint256 _endDate; 
        uint256 _rent; 
        uint256 _deposit; 
        uint256 _occupancyLimit; 
        uint256 _stampDuty; 
        ContractUtility.DisputeType _dispute;
    }
    
    leaseDetails details;

    event InitializeRent(uint256 _value);
    event PayRent(uint256 _value);
    event WithdrawRent(address _landlord, address _tenant, uint256 _value);
    event TerminateRent(address _landlord, address _tenant, uint256 _value);
    event ExtendEndDate(address _landlord, address _tenant, uint256 _period);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    modifier isActive() {
        require(details.lease.state == ContractUtility.LeaseState.ACTIVE, "Lease should be active!");
        _;
    }

    modifier tenantOnly() {
        require(msg.sender == details.lease.tenant, "Only tenant can call this function!");
        _;
    }

    modifier landlordOnly() {
        require(msg.sender == details.lease.landlord, "Only landlord can call this function!");
        _;
    }

    modifier checkPaymentDate() {
        require(block.timestamp >= details.lease.paymentDate, "Payment date has not reached!");
        _;
    }

    constructor(leaseInput memory input) {
        
        details.lease = ContractUtility.Lease(
            input._landlord,
            input._tenant,
            input._description,
            ContractUtility.LeaseState.PENDING,
            input._startDate,
            input._endDate,
            input._startDate.add(30 days),
            input._rent,
            input._deposit,
            input._occupancyLimit,
            input._stampDuty
        );

        details.base = input._base;
        details.cummulativePaymentCount = 0;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.LEASE,
            input._dispute, 
            input._landlord, 
            input._tenant, 
            input._walletLandlord, 
            input._walletTenant
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // get the payment amount for the first payment
    function getFirstPayment() public view returns (uint256) {
        return details.lease.rent.add(details.lease.deposit).add(details.lease.rent.mul(details.lease.stampDuty).div(100));
    }

    // initiate the rent and pay deposit
    function initRent() external payable contractReady tenantOnly checkPaymentDate {
        require(details.lease.state == ContractUtility.LeaseState.PENDING, "Lease should be pending!");
        require(msg.value == getFirstPayment(), "Payment amount is incorrect!");

        details.lease.paymentDate = details.lease.paymentDate.add(30 days);
        details.lease.state = ContractUtility.LeaseState.ACTIVE;
        details.cummulativePaymentCount = details.cummulativePaymentCount.add(1);

        emit InitializeRent(msg.value);
    }

    // pay the rent by the tenant
    function pay() external payable contractReady tenantOnly isActive checkPaymentDate {
        require(msg.value == details.lease.rent, "Payment amount is incorrect!");

        details.lease.paymentDate = details.lease.paymentDate.add(30 days);
        details.cummulativePaymentCount = details.cummulativePaymentCount.add(1);

        emit PayRent(msg.value);
    }

    // withdraw the payment by the landlord
    function withdraw() public contractReady landlordOnly {
        require(address(this).balance - details.lease.deposit >= details.lease.rent.mul(details.cummulativePaymentCount), "No payment to withdraw!");

        details.lease.landlord.transfer(details.lease.rent.mul(details.cummulativePaymentCount));
        details.cummulativePaymentCount = 0;

        emit WithdrawRent(details.lease.landlord, details.lease.tenant, details.lease.rent.mul(details.cummulativePaymentCount));
    }

    // terminate the contract
    function terminate() public contractReady isActive {
        require(msg.sender == details.lease.tenant || msg.sender == details.lease.landlord, "You are not involved in this contract!");
        require((block.timestamp >= details.lease.endDate  ||  block.timestamp > details.lease.paymentDate.add(90 days)), 
            "Termination condition has not reached!");
        require(details.cummulativePaymentCount == 0, "Payment has not been withdraw!");

        if (block.timestamp >= details.lease.endDate) {
            details.lease.tenant.transfer(details.lease.deposit);
            details.base.completeContract(details.contractId);

        } else {
            details.base.voidContract(details.contractId);
        }

        emit TerminateRent(details.lease.landlord, details.lease.tenant, details.lease.rent.mul(details.cummulativePaymentCount));

        details.lease.state = ContractUtility.LeaseState.TERMINATED;
    }

    // extend the contract end date
    function extendEndDate(uint256 _period) public contractReady landlordOnly isActive() {
        require(block.timestamp < details.lease.endDate, "Contract has already ended!");

        details.lease.endDate = details.lease.endDate.add(_period.mul(30 days));

        emit ExtendEndDate(details.lease.landlord, details.lease.tenant, _period);
    }
}