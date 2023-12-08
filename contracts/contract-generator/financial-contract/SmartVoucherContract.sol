// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../ContractUtility.sol";
import "../BaseContract.sol";

/**
 * @title details.smartVoucherContract
 * @dev The base contract for smart voucher contract
 */
contract smartVoucherContract {

    struct voucherDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.SmartVoucher smartVoucher;
    }

    struct voucherInput {
        BaseContract _base; 
        address _issuer; 
        address _redeemer; 
        address _usageAddress; 
        address _walletIssuer; 
        address _walletRedeemer; 
        string _description; 
        ContractUtility.VoucherType _voucherType; 
        uint256 _value; 
        uint256 _expiryDate;
        ContractUtility.DisputeType _dispute;
    }
    
    voucherDetails details;

    event ContractTerminated(address _issuer, address _redeemer, uint256 _value);
    event ContractRedeemed(address _issuer, address _redeemer, uint256 _value);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    constructor(voucherInput memory input) {
        details.smartVoucher = ContractUtility.SmartVoucher(
            input._issuer,
            input._redeemer,
            input._usageAddress,
            input._description,
            input._voucherType,
            ContractUtility.VoucherState.ACTIVE,
            input._value,
            input._expiryDate
        );

        details.base = input._base;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.SMART_VOUCHER,
            input._dispute, 
            input._issuer, 
            input._redeemer, 
            input._walletIssuer, 
            input._walletRedeemer
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // redeem the voucher
    function redeem() public contractReady returns (address, ContractUtility.VoucherType, uint256) {
        require(msg.sender == details.smartVoucher.redeemer, "You are not the redeemer!");
        require(details.smartVoucher.state == ContractUtility.VoucherState.ACTIVE, "Voucher should be active!");
        require(block.timestamp <= details.smartVoucher.expiryDate, "Voucher has expired!");

        details.smartVoucher.state = ContractUtility.VoucherState.REDEEMED;

        emit ContractTerminated(details.smartVoucher.issuer, details.smartVoucher.redeemer, details.smartVoucher.value);
        return (details.smartVoucher.usageAddress, details.smartVoucher.voucherType, details.smartVoucher.value);
    }

    // destroy the voucher
    function destroy() public contractReady {
        require(details.smartVoucher.state == ContractUtility.VoucherState.REDEEMED ||
            block.timestamp > details.smartVoucher.expiryDate, "Voucher is usable!");

        details.base.completeContract(details.contractId);

        emit ContractTerminated(details.smartVoucher.issuer, details.smartVoucher.redeemer, details.smartVoucher.value);
    }
}