// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./LicenseOwningContract.sol";
import "../ContractUtility.sol";
import "../BaseContract.sol";

/**
 * @title ContentLicensingContract
 * @dev The base contract for content licensing contract
 */
contract ContentLicensingContract {
    using SafeMath for uint256;

    struct licenseDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.ContentLicensing contentLicensing;
        bool terminating;
        bool isWithdrawn;
    }   

    struct licenseInput {
        BaseContract _base; 
        address payable _owner;
        address payable _licensee;
        address _walletOwner; 
        address _walletLicensee; 
        LicenseOwningContract _license; 
        uint256 _startDate; 
        ContractUtility.DisputeType _dispute;
    }

    licenseDetails details;

    event PayLicense(address _licensee, address _owner, uint256 _value);
    event WithdrawLicense(address _owner, address _licensee, uint256 _value);
    event ExtendLicense(address _licensee, address _owner, uint256 _value);
    event TerminateLicense(address _licensee, address _owner);  
    event ContractTerminated(address _licensee, address _owner);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    constructor(licenseInput memory input) {

        require(input._owner == input._license.getOwner(), 
            "Owner of the license is not the same as the owner of the contract!");
        
        details.contentLicensing = ContractUtility.ContentLicensing(
            input._owner,
            input._licensee,
            input._license,
            ContractUtility.LicenseState.PENDING,
            input._license.getLicensePrice(),
            input._startDate,
            input._startDate.add(input._license.getLicenseRenewalPeriod()));

        details.base = input._base;
        details.terminating = false;
        details.isWithdrawn = false;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.CONTENT_LICENSING,
            input._dispute, 
            input._owner, 
            input._licensee, 
            input._walletOwner, 
            input._walletLicensee
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // pay the licensor
    function pay() external payable contractReady {
        require(msg.sender == details.contentLicensing.licensee, "You are not the licensee!");
        require(details.contentLicensing.state == ContractUtility.LicenseState.PENDING, "License should be pending!");
        require(msg.value == details.contentLicensing.price, "Payment amount is incorrect!");

        details.contentLicensing.state = ContractUtility.LicenseState.ACTIVE;

        emit PayLicense(details.contentLicensing.licensee, details.contentLicensing.owner, details.contentLicensing.price);
    }

    
    function withdraw() public contractReady {
        require(msg.sender == details.contentLicensing.owner, "You are not the owner!");
        require(address(this).balance >= details.contentLicensing.price, "No payment to withdraw!");
        require(details.contentLicensing.state == ContractUtility.LicenseState.ACTIVE, 
            "License should be active!");
        
        details.contentLicensing.owner.transfer(details.contentLicensing.price);
        details.isWithdrawn = true;

        emit WithdrawLicense(details.contentLicensing.owner, details.contentLicensing.licensee, details.contentLicensing.price);
    }

    // extend the license
    function extend() external payable contractReady {
        require(msg.sender == details.contentLicensing.licensee, "You are not the licensee!");
        require(!details.terminating, "Contract is terminating!");
        require(block.timestamp >= details.contentLicensing.endDate.sub(30 days), 
            "Only can be renewed 30 days before the license expires!");
        require(details.contentLicensing.state == ContractUtility.LicenseState.ACTIVE, "License should be active!");
        require(msg.value == details.contentLicensing.price, "Payment amount is incorrect!");

        details.contentLicensing.endDate = details.contentLicensing.endDate.add(details.contentLicensing.license.getLicenseRenewalPeriod());
        details.isWithdrawn = false;

        emit ExtendLicense(details.contentLicensing.licensee, details.contentLicensing.owner, details.contentLicensing.price);
    }

    // terminate the contract
    // disable license renewal
    function terminate() public contractReady {
        require(msg.sender == details.contentLicensing.owner || msg.sender == details.contentLicensing.licensee, 
            "You are not involved in this contract!");
        require(!details.terminating, "Contract is already terminating!");

        details.terminating = true;

        emit TerminateLicense(details.contentLicensing.licensee, details.contentLicensing.owner);
    }

    // destruct the contract
    function destructContract() public contractReady {
        require(block.timestamp > details.contentLicensing.endDate, "Contract is not terminating!");
        require(details.isWithdrawn, "Payment has not been withdrawn!");

        details.base.completeContract(details.contractId);

        details.contentLicensing.state = ContractUtility.LicenseState.EXPIRED;

        emit ContractTerminated(details.contentLicensing.licensee, details.contentLicensing.owner);
    }
}