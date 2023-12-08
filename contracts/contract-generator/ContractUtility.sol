// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../dispute-resolution-v1/Dispute.sol";
import "./intellectual-property/LicenseOwningContract.sol";

/**
 * @title Contract Utility
 * @dev This contract contains all the utility functions for the contracts.
 *
 * It contains:
    * Enumerations for contract types, dispute types, and tiers.
    * Structs for common, future, option, bond, fund, stock, lend-borrow, simple payment, 
      smart voucher, content licensing, lease, purchase, and service contracts, with some
      related enumerations.
    * Function to get contract cost based on contract type, verifier amount and contract completion 
      reward for each tier.
 */

library ContractUtility {
    enum ContractState {
        DRAFT,
        SIGNED,
        INPROGRESS,
        DISPUTED,
        COMPLETED,
        VOIDED
    }

    enum ContractType {
        COMMON,
        FUTURE,
        OPTION,
        BOND,
        FUND,
        STOCK,
        LEND_BORROW_ETH,
        SIMPLE_PAYMENT,
        SMART_VOUCHER,
        CONTENT_LICENSING,
        LEASE,
        PURCHASE,
        SERVICE
    }

    enum DisputeType {
        NONE,
        V1
    }

    enum VerificationState {
        PENDING,
        LEGITIMATE,
        FRAUDULENT
    }

    struct Signature {
        address payer;
        bytes32 _ad1;
        address payee;
        bytes32 _ad2;
        uint8 isSigned; // 0: not signed, 1: signed by one party, 2: signed by both parties
    }

    // basic properties that are shared among all contracts
    struct BasicProperties {
        uint256 id;
        ContractUtility.ContractState state;
        uint256 creationTime;
        ContractUtility.ContractType contractType;
        ContractUtility.DisputeType disputeType;
        ContractUtility.Signature signature;
        ContractUtility.VerificationState isVerified;
        uint8 verifierNeeded;
        uint256 legitAmount;
        uint256 fraudAmount;
        bool completed;
        uint256 verificationStart;
    }

    struct ContractRepoInput {
        address _contractAddress;
        ContractUtility.ContractType _contractType;
        ContractUtility.DisputeType _dispute;
        address _payee;
        address _payer;
        address _walletPayee;
        address _walletPayer;
    }

    struct Common {
        string title;
        string contractType;
        address payable initiator;
        address payable respondent;
        string[] obligationTitle;
        string[] obligationDescription;
        uint256[] paymentAmount;
        address payable[] payer;
        address payable[] payee;
    }

    enum DerivativeState {
        PENDING,
        ACTIVE,
        EXPIRED
    }

    struct Future {
        address payable seller;
        address payable buyer;
        DerivativeState state;
        string assetType;
        uint256 assetCode;
        uint256 quantity;
        uint256 deliveryDate;
        uint256 futurePrice;
        uint256 margin;
        string description;
    }

    enum OptionType {
        CALL,
        PUT
    }

    struct Option {
        address payable optionSeller; // short position
        address payable optionBuyer; // long position
        DerivativeState state;
        OptionType optionType;
        string assetType;
        uint256 assetCode;
        uint256 quantity;
        uint256 deliveryDate;
        uint256 strikePrice;
        uint256 optionPremium;
    }

    enum SecuritiesState {
        ISSUED,
        ACTIVE,
        REDEEMED
    }

    struct Bond {
        address payable issuer;
        address payable owner;
        string bondName;
        string bondCode;
        SecuritiesState state;
        uint256 quantity;
        uint256 issueDate;
        uint256 maturity;
        uint256 couponRate;
        uint256 couponPaymentInterval;
        uint256 bondPrice;
        uint256 faceValue;
        uint256 redemptionValue;
        uint256 couponPaymentDate;
    }

    struct Fund {
        string fundName;
        string fundDescription;
        address payable fundManager;
        address payable fundHolder;
        SecuritiesState state;
        uint256 fundValue;
        uint256 fundShares;
        uint256 yieldRate;
        uint256 interestInterval;
        uint256 commisionRate;
        uint256 interestPaymentDate;
    }

    struct Stock {
        address payable issuer;
        address payable shareholder;
        string stockName;
        string stockCode;
        SecuritiesState state;
        uint256 stockValue;
        uint256 shares;
        uint256 dividenRate;
        uint256 dividenPaymentInterval;
        uint256 dividenPaymentDate;
    }

    struct LendBorrow {
        address payable borrower;
        address payable lender;
        uint256 contractDuration;
        uint256 amount;
        uint256 releaseTime;
        uint256 interestRate;
    }

    struct SimplePayment {
        address payable payer;
        address payable payee;
        uint256 amount;
        uint256 paymentDate;
        string description;
    }

    enum VoucherType {
        DISCOUNT,
        GIFT
    }
    enum VoucherState {
        ACTIVE,
        REDEEMED
    }

    struct SmartVoucher {
        address issuer;
        address redeemer;
        address usageAddress;
        string description;
        VoucherType voucherType;
        VoucherState state;
        uint256 value;
        uint256 expiryDate;
    }

    enum LicenseState {
        PENDING,
        ACTIVE,
        EXPIRED
    }

    struct ContentLicensing {
        address payable owner;
        address payable licensee;
        LicenseOwningContract license;
        LicenseState state;
        uint256 price;
        uint256 startDate;
        uint256 endDate;
    }

    enum LeaseState {
        PENDING,
        ACTIVE,
        TERMINATED
    }

    struct Lease {
        address payable landlord;
        address payable tenant;
        string description;
        LeaseState state;
        uint256 startDate;
        uint256 endDate;
        uint256 paymentDate;
        uint256 rent;
        uint256 deposit;
        uint256 occupancyLimit;
        uint256 stampDuty;
    }

    struct Purchase {
        address payable seller;
        address payable buyer;
        string description;
        uint256 price;
        uint256 paymentDate;
        uint256 deliveryDate;
    }

    enum ServiceType {
        FREELANCE,
        SUBCRIPTION
    }

    struct Service {
        ServiceType serviceType;
        address payable serviceProvider;
        address payable client;
        uint256 contractDuration;
        string description;
        uint256 paymentTerm;
        uint256 singlePayment;
        uint256 paymentDate;
    }

}
