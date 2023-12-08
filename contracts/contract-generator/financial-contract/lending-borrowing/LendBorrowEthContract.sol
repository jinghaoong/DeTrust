// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "../../ContractUtility.sol";
import "../../BaseContract.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LendBorrowEthContract {
    using SafeMath for uint256;

    struct lendDetails {
        BaseContract base;
        uint256 contractId;
        address payable escrow; 
        ContractUtility.LendBorrow lendBorrowEth;
        bool isLended;
        bool isBorrowed;
        bool isRepaid;
        bool isRetrieved;
    }

    struct lendInput {
        BaseContract _base; 
        address payable _borrower; 
        address payable _lender; 
        address _walletBorrower; 
        address _walletLender; 
        uint256 _contractDuration; 
        uint256 _releaseTime; 
        ContractUtility.DisputeType _dispute;  
        uint256 _amount; 
        uint256 _interestRate;
    }
    
    lendDetails details;

    event Lend(address indexed from, address indexed to, uint256 value);
    event Borrow(address indexed from, address indexed to, uint256 value);
    event Repay(address indexed from, address indexed to, uint256 value);
    event Retrieve(address indexed from, address indexed to, uint256 value);
    event Terminate(address indexed from);
    event SetInterestRate(uint256 value);

    modifier contractReady() {
        require(details.base.isContractReady(details.contractId), "Contract is not ready!");
        _;
    }

    constructor(lendInput memory input) {
    
        details.lendBorrowEth = ContractUtility.LendBorrow(
            input._borrower,
            input._lender,
            input._contractDuration.mul(1 days),
            input._amount,
            input._releaseTime,
            input._interestRate
            );

        details.base = input._base;
        details.escrow = payable(address(this));
        details.isBorrowed = false;
        details.isLended = false;
        details.isRepaid = false;
        details.isRetrieved = false;

        ContractUtility.ContractRepoInput memory repoInput = ContractUtility.ContractRepoInput(
            address(this), 
            ContractUtility.ContractType.LEND_BORROW_ETH,
            input._dispute, 
            input._lender, 
            input._borrower, 
            input._walletLender, 
            input._walletBorrower
        );

        details.contractId = details.base.addToContractRepo(repoInput);
    
    }

    // lender lend the amount
    function lend() public payable contractReady {
        require(msg.sender == details.lendBorrowEth.lender, "You are not the lender!");
        require(!details.isLended, "The amount has been released!");
        require(msg.value == details.lendBorrowEth.amount, "The amount is not correct!");

        details.isLended = true;

        emit Lend(msg.sender, address(this), msg.value);
    }

    // borrower borrow the amount after the release time
    function borrow() public contractReady {
        require(msg.sender == details.lendBorrowEth.borrower, "You are not the borrower!");
        require(block.timestamp >= details.lendBorrowEth.releaseTime, "The release time has not reached!");
        require(details.isLended, "The amount has not been released!");
        require(address(this).balance >= details.lendBorrowEth.amount, "The contract does not have enough balance!");

        details.lendBorrowEth.borrower.transfer(details.lendBorrowEth.amount);
        details.isBorrowed = true;

        emit Borrow(address(this), msg.sender, details.lendBorrowEth.amount);
    }

    // get the amount should be repaid after added with interest
    function getRepayAmount() public view contractReady returns (uint256) {
        return details.lendBorrowEth.amount.add(details.lendBorrowEth.amount.mul(
            details.lendBorrowEth.interestRate).div(100) ** (
            block.timestamp.sub(details.lendBorrowEth.releaseTime)).div(30 days));
    }

    // borrower repay the amount
    function repay() public payable contractReady {
        require(msg.sender == details.lendBorrowEth.borrower, "You are not the borrower!");
        require(details.isBorrowed, "The amount has not been borrowed!");
        require(msg.value == getRepayAmount(), "The repay amount is not correct!");

        details.isRepaid = true;

        emit Repay(msg.sender, address(this), msg.value);
    }

    // lender retrieve the amount after the borrower repaid
    function retrieve() public contractReady {
        require(msg.sender == details.lendBorrowEth.lender, "You are not the lender!");
        require(details.isRepaid, "The amount has not been repaid!");
        require(address(this).balance >= getRepayAmount(), "The contract does not have enough balance!");

        details.lendBorrowEth.lender.transfer(getRepayAmount());
        details.isRetrieved = true;

        emit Retrieve(address(this), msg.sender, getRepayAmount());
    }

    // terminate the contract
    function terminate() public contractReady {
        require(details.isRetrieved || 
            !details.isBorrowed && block.timestamp > details.lendBorrowEth.releaseTime.add(details.lendBorrowEth.contractDuration), 
            "Termination not available!");
        require(msg.sender == details.lendBorrowEth.lender || msg.sender == details.lendBorrowEth.borrower, 
            "You are not involved in this contract!");

        if (details.isLended && !details.isBorrowed) {
            details.lendBorrowEth.lender.transfer(details.lendBorrowEth.amount);
            details.base.voidContract(details.contractId);
        } else if (details.isRetrieved) {
            details.base.completeContract(details.contractId);
        } else {
            details.base.voidContract(details.contractId);
        }

        emit Terminate(address(this));
    }

    // change final interest rate
    function setInterestRate(uint256 _newRate) public contractReady {
        require(msg.sender == details.lendBorrowEth.lender, "You are not the lender!");
        details.lendBorrowEth.interestRate = _newRate;

        emit SetInterestRate(_newRate);
    }

}