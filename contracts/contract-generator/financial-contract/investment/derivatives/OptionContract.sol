// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../ContractUtility.sol";
import "../../../BaseContract.sol";

/**
 * @title OptionContract
 * @dev The base contract for details.option contract
 */
contract OptionContract {
    using SafeMath for uint256;

    struct optionDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.Option option;
        bool premiumPaid;
        bool isExercised;
    }

    struct optionInput {
        BaseContract _base; 
        address payable _seller; 
        address payable _buyer;
        address _walletSeller; 
        address _walletBuyer; 
        ContractUtility.OptionType _optionType;  
        uint256 _assetCode; 
        string _assetType; 
        uint256 _quantity; 
        uint256 _deliveryDate; 
        uint256 _strikePrice;
        uint256 _optionPremium;
        ContractUtility.DisputeType _dispute;
    }
    
    optionDetails details;

    event ContractInit(uint256 _value);
    event PurchaserVerified();
    event OptionExercised();
    event OptionCancelled();
    event OptionReverted();
    event VerifyTransfer();

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    modifier purchaserOnly() {
        require((details.option.optionType == ContractUtility.OptionType.CALL && msg.sender == details.option.optionBuyer) ||
            (details.option.optionType == ContractUtility.OptionType.PUT && msg.sender == details.option.optionSeller), 
            "You are not qualified to execute this function");
        _;
    }

    modifier optionCanExercise() {
        require(msg.sender == details.option.optionBuyer, "You are not the option buyer!");
        require(details.option.state == ContractUtility.DerivativeState.ACTIVE, "Option contract is not active!");
        require(block.timestamp >= details.option.deliveryDate, "Delivery date has not reached!");
        _;
    }

    constructor(optionInput memory input) {
        
        details.option = ContractUtility.Option(
            input._seller,
            input._buyer,
            ContractUtility.DerivativeState.PENDING,
            input._optionType,
            input._assetType,
            input._assetCode,
            input._quantity,
            block.timestamp.add(input._deliveryDate.mul(1 days)),
            input._strikePrice,
            input._optionPremium);
        
        details.base = input._base;
        details.premiumPaid = false;
        details.isExercised = false;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.OPTION,
            input._dispute, 
            input._seller, 
            input._buyer, 
            input._walletSeller, 
            input._walletBuyer
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // buyer of the option init the contract by paying the premium to the contract
    function buyerInit() external payable contractReady purchaserOnly {
        require(details.option.state == ContractUtility.DerivativeState.PENDING, "Option contract has been verified!");        
        require(msg.sender == details.option.optionBuyer, "You are not the buyer!");
        require(msg.value == details.option.optionPremium, "Option premium is not correct!");

        details.option.optionSeller.transfer(details.option.optionPremium);
        details.premiumPaid = true;
        
        emit ContractInit(msg.value);
    }

    // purchaser of goods agrees and sends strike price to the contract
    function purchaserVerify() external payable contractReady purchaserOnly {
        require(msg.value == details.option.strikePrice.mul(details.option.quantity), "Amount is not correct!");
        require(details.premiumPaid, "Premium has not been paid!");

        details.option.state = ContractUtility.DerivativeState.ACTIVE;

        emit PurchaserVerified();
    }

    // purchaser verifies product delivery
    function verifyTransfer() public contractReady {
        require(details.isExercised, "Option has not been exercised!");

        details.option.state = ContractUtility.DerivativeState.EXPIRED;
        details.base.completeContract(details.contractId);

        emit VerifyTransfer();
    }

    // buyer of option exercise the details.option
    function exerciseOption() public contractReady optionCanExercise {
        require(address(this).balance >= details.option.strikePrice.mul(details.option.quantity), "Contract does not have enough money to exercise!");
        
        if (details.option.optionType == ContractUtility.OptionType.CALL) {
            // if the details.option is call, the buyer can exercise the details.option
            details.option.optionSeller.transfer(details.option.strikePrice.mul(details.option.quantity));

        } else {
            // if the details.option is put, the seller can exercise the details.option
            details.option.optionBuyer.transfer(details.option.strikePrice.mul(details.option.quantity));
            
        }

        details.isExercised = true;

        emit OptionExercised();
    }

    // buyer of details.option cancel the details.option
    function cancelExercise() public contractReady optionCanExercise {
        require(address(this).balance >= details.option.strikePrice.mul(details.option.quantity).add(details.option.strikePrice.mul(details.option.quantity)), 
            "Contract does not have enough money to exercise!");

        if (details.option.optionType == ContractUtility.OptionType.PUT) {
            details.option.optionBuyer.transfer(details.option.strikePrice.mul(details.option.quantity));
            details.option.optionSeller.transfer(details.option.strikePrice.mul(details.option.quantity));

        } else {
            details.option.optionBuyer.transfer(details.option.strikePrice.mul(details.option.quantity));
            details.option.optionBuyer.transfer(details.option.strikePrice.mul(details.option.quantity));
        }
        details.base.completeContract(details.contractId);

        emit OptionCancelled();
    }

    // revert the details.option contract before paying the strike price
    function revertOption() external payable contractReady {
        require(msg.sender == details.option.optionBuyer || msg.sender == details.option.optionSeller, 
            "You are not involved in this details.option!");
        require(details.option.state == ContractUtility.DerivativeState.PENDING, 
            "Option contract has been activated!");
        require(address(this).balance >= details.option.strikePrice.mul(details.option.quantity), 
            "Contract does not have enough money to exercise!");

        if (details.option.optionType == ContractUtility.OptionType.CALL) {
            details.option.optionBuyer.transfer(details.option.optionPremium);

        } else {
            details.option.optionSeller.transfer(details.option.optionPremium);

        }

        details.base.voidContract(details.contractId);
        emit OptionReverted();
    }

}