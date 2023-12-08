// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../../DeTrustToken.sol";
import "../../../ContractUtility.sol";
import "../../../BaseContract.sol";

/**
 * @title StockContract
 * @dev The base contract for details.stock contract
 */
contract StockContract {
    using SafeMath for uint256;

    struct stockDetails {
        BaseContract base;
        uint256 contractId;
        ContractUtility.Stock stock;
        uint256 dividenValue;
        bool isFundCollected;
        bool isFundReturned;
    }
    
    struct stockInput {
        BaseContract _base; 
        address payable _issuer; 
        address payable _shareHolder; 
        address _walletIssuer; 
        address _walletShareHoler; 
        string _stockName; 
        string _stockCode; 
        uint256 _stockValue; 
        uint256 _shares; 
        uint256 _dividenRate; 
        uint256 _dividenPaymentInterval; 
        uint256 _firstDividenDate; 
        ContractUtility.DisputeType _dispute;
    }

    stockDetails details;

    event BuyStock(uint256 _value);
    event TransferStock(address _transferee);
    event CollectFund();
    event PayDividen(uint256 _value);
    event RedeemDividen();
    event ReturnFund();
    event UpdateDividenRate(uint256 _value);
    event UpdateStockValue(uint256 _value);
    event EndStockContract(uint256 _value);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    modifier issuerOnly() {
        require(msg.sender == details.stock.issuer, "Only issuer can call this function!");
        _;
    }

    modifier shareholderOnly() {
        require(msg.sender == details.stock.shareholder, "Only shareholder can call this function!");
        _;
    }

    modifier isActive() {
        require(details.stock.state == ContractUtility.SecuritiesState.ACTIVE, "Stock should be active!");
        _;
    }

    constructor(stockInput memory input) {
        
        details.stock = ContractUtility.Stock(
            input._issuer,
            input._shareHolder,
            input._stockName,
            input._stockCode,
            ContractUtility.SecuritiesState.ISSUED,
            input._stockValue,
            input._shares,
            input._dividenRate,
            input._dividenPaymentInterval,
            input._firstDividenDate
        );

        details.base = input._base;
        details.dividenValue = 0;
        details.isFundCollected = false;
        details.isFundReturned = false;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.STOCK,
            input._dispute, 
            input._issuer, 
            input._shareHolder, 
            input._walletIssuer, 
            input._walletShareHoler
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    }

    // buy the stock
    function buy() external payable contractReady shareholderOnly {
        require(details.stock.state == ContractUtility.SecuritiesState.ISSUED, "Stock should be issuing!");
        require(msg.value == details.stock.stockValue.mul(details.stock.shares), "The amount is not correct!");

        details.stock.state = ContractUtility.SecuritiesState.ACTIVE;

        emit BuyStock(msg.value);
    }

    // transfer the stock
    function transfer(address payable _transferee) public contractReady {
        require(msg.sender == details.stock.shareholder, "You are not the shareholder!");
        
        details.stock.shareholder = _transferee;

        emit TransferStock(_transferee);
    }

    // collect fund from shareholders
    function collectFund() public contractReady issuerOnly isActive {
        require(!details.isFundCollected, "Fund has been collected!");

        details.stock.issuer.transfer(details.stock.stockValue.mul(details.stock.shares));
        details.isFundCollected = true;

        emit CollectFund();
    }

    // pay dividen to shareholders
    function payDividen() external payable contractReady issuerOnly isActive {
        require(block.timestamp >= details.stock.dividenPaymentDate, "dividen payment date has not reached!");
        require(msg.value == details.stock.stockValue.mul(details.stock.shares).mul(details.stock.dividenRate).div(100), 
            "The amount is not correct!");

        details.dividenValue = details.dividenValue.add(msg.value);
        details.stock.dividenPaymentDate = details.stock.dividenPaymentDate.add(details.stock.dividenPaymentInterval);

        emit PayDividen(msg.value);
    }

    // shareholder redeems dividen
    function redeemDividen() public contractReady shareholderOnly isActive {
        require(details.dividenValue > 0, "No dividen to redeem!");
        require(address(this).balance >= details.dividenValue.add(details.stock.stockValue.mul(details.stock.shares)), 
            "The contract does not have enough balance!");

        details.stock.shareholder.transfer(details.dividenValue);
        details.dividenValue = 0;

        emit RedeemDividen();
    }

    // return fund to shareholder
    function returnFund() external payable contractReady issuerOnly isActive {
        require(msg.value == details.stock.stockValue.mul(details.stock.shares), "The amount is not correct!");
        require(!details.isFundReturned, "Fund has been returned!");

        details.isFundReturned = true;

        emit ReturnFund();
    }

    // update the dividen rate
    function updateDividenRate(uint256 _newDividenRate) public contractReady issuerOnly {
        
        details.stock.dividenRate = _newDividenRate;

        emit UpdateDividenRate(_newDividenRate);
    }

    // update the stock value
    function updateStockValue(uint256 _newStockValue) public contractReady issuerOnly {
        
        details.stock.stockValue = _newStockValue;

        emit UpdateStockValue(_newStockValue);
    }

    // terminate the stock contract
    function endStockContract() public contractReady isActive {
        require(msg.sender == details.stock.issuer || msg.sender == details.stock.shareholder, "You are not involved in this contract!");
        require(details.dividenValue == 0, "Dividen should be redeemed first!");
        require(details.isFundReturned, "Please wait for the return of fund first!");
        require(address(this).balance >= details.stock.stockValue.mul(details.stock.shares), "Insufficient fund value!");

        details.stock.shareholder.transfer(details.stock.stockValue.mul(details.stock.shares));
        details.stock.state = ContractUtility.SecuritiesState.REDEEMED;
        details.base.completeContract(details.contractId);
        emit EndStockContract(details.stock.stockValue.mul(details.stock.shares));
    }
}