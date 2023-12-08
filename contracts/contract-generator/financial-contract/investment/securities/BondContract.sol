// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../../DeTrustToken.sol";
import "../../../ContractUtility.sol";
import "../../../BaseContract.sol";

/**
 * @title StockContract
 * @dev The base contract for stock contract
 */
contract BondContract {
    using SafeMath for uint256;

    struct bondDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.Bond bond;
        uint256 cummulativeCouponValue;
        bool isRedemptionReady;
        bool isFundCollected;
    }

    struct bondInput {
        BaseContract _base; 
        address payable _issuer; 
        address payable _owner;
        address _walletIssuer; 
        address _walletOwner; 
        string _bondName; 
        string _bondCode; 
        uint256 _quantity; 
        uint256 _issueDate; 
        uint256 _maturity; 
        uint256 _couponRate; 
        uint256 _couponPaymentInterval; 
        uint256 _faceValue; 
        uint256 _redemptionValue; 
        ContractUtility.DisputeType _dispute;
    }
    
    bondDetails details;

    event BuyBond(uint256 _value);
    event TransferBond(address _transferee);
    event CollectFund(uint256 _value);
    event PayCoupon(uint256 _value);
    event PayRedemption(uint256 _value);
    event RedeemCoupon(uint256 _value);
    event EndBond(uint256 _value);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    modifier issuerOnly() {
        require(msg.sender == details.bond.issuer, "Only issuer can call this function!");
        _;
    }

    modifier bondHolderOnly() {
        require(msg.sender == details.bond.owner, "Only bond holder can call this function!");
        _;
    }

    modifier isActive() {
        require(details.bond.state == ContractUtility.SecuritiesState.ACTIVE, "Bond should be active!");
        _;
    }

    constructor(bondInput memory input) {
        
        details.bond = ContractUtility.Bond(
            input._issuer,
            input._owner,
            input._bondName, // contract title
            input._bondCode,
            ContractUtility.SecuritiesState.ISSUED,
            input._quantity,
            input._issueDate,
            input._issueDate.add(input._maturity.mul(365 days)),
            input._couponRate,
            input._couponPaymentInterval,
            input._faceValue.mul(input._quantity),
            input._faceValue,
            input._redemptionValue,
            input._issueDate.add(input._couponPaymentInterval.mul(30 days))
        );

        details.base = input._base;
        details.cummulativeCouponValue = 0;
        details.isRedemptionReady = false;
        details.isFundCollected = false;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.BOND,
            input._dispute, 
            input._issuer, 
            input._owner, 
            input._walletIssuer, 
            input._walletOwner
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // buy the bond
    function buy() external payable contractReady bondHolderOnly {
        require(details.bond.state == ContractUtility.SecuritiesState.ISSUED, "Bond should be issuing!");
        require(msg.value == details.bond.bondPrice.mul(details.bond.quantity), "The amount is not correct!");

        details.bond.state = ContractUtility.SecuritiesState.ACTIVE;

        emit BuyBond(msg.value);
    }

    // sell the bond
    function transfer(address payable _transferee) public contractReady bondHolderOnly isActive {
        require(block.timestamp >= details.bond.maturity, "Bond has been redeemed");
        details.bond.owner = _transferee;

        emit TransferBond(_transferee);
    }

    // bond issuer collect fund (details.bond price) paid
    function collectFund() public contractReady issuerOnly isActive {
        require(!details.isFundCollected, "Fund has been collected!");

        details.bond.issuer.transfer(details.bond.bondPrice.mul(details.bond.quantity));
        details.isFundCollected = true;

        emit CollectFund(details.bond.bondPrice.mul(details.bond.quantity));
    }

    // bond issuer pays coupon to details.bond holder periodically
    function payCoupon() external payable contractReady issuerOnly isActive {
        require(block.timestamp >= details.bond.couponPaymentDate, "Coupon payment date has not reached!");
        require(msg.value == details.bond.couponRate.mul(details.bond.faceValue).mul(details.bond.quantity)
            .div(details.bond.couponPaymentInterval).div(100), "The amount is not correct!");
        
        details.cummulativeCouponValue = details.cummulativeCouponValue.add(msg.value);
        details.bond.couponPaymentDate = details.bond.couponPaymentDate.add(details.bond.couponPaymentInterval);

        emit PayCoupon(msg.value);
    }

    // bond issuer pays redemption value to details.bond holder at the last term of details.bond
    function payRedemption() external payable contractReady issuerOnly isActive {
        require(block.timestamp >= details.bond.maturity, "Bond has not matured!");
        require(msg.value == details.bond.redemptionValue.mul(details.bond.quantity), 
            "The amount is not correct!");
        require(!details.isRedemptionReady, "Redemption is ready!");
        
        details.isRedemptionReady = true;

        emit PayRedemption(msg.value);
    }

    // bond holder redeems coupon, assume coupon could be redeemed once released
    function redeemCoupon() public contractReady bondHolderOnly isActive {
        require(details.cummulativeCouponValue > 0, "No coupon to redeem!");
        require(address(this).balance >= details.cummulativeCouponValue, "Insufficient balance!");

        details.bond.owner.transfer(details.cummulativeCouponValue);
        details.cummulativeCouponValue = 0;

        emit RedeemCoupon(details.cummulativeCouponValue);
    }

    // complete contract
    function endBond() public contractReady isActive {
        require(msg.sender == details.bond.issuer || msg.sender == details.bond.owner, "You are not invloved in this details.bond!");
        require(block.timestamp >= details.bond.maturity, "Bond has not matured!");
        require(details.isRedemptionReady, "Redemption is not ready!");
        require(details.cummulativeCouponValue == 0, "Coupon has not been redeemed!");
        require(address(this).balance >= details.bond.redemptionValue.mul(details.bond.quantity), 
            "Insufficient balance!");

        details.bond.owner.transfer(details.bond.redemptionValue.mul(details.bond.quantity));
        details.bond.state = ContractUtility.SecuritiesState.REDEEMED;
        details.base.completeContract(details.contractId);
        emit EndBond(details.bond.redemptionValue.mul(details.bond.quantity));
    }
}