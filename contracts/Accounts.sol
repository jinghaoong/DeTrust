// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

contract Accounts {
    address private owner;

    enum AccountType {
        USER,
        MODERATOR,
        ADMIN
    }

    struct Account {
        bool isActive;
        uint256 accountNumber;
        AccountType accountType;
    }

    mapping(address => Account) private accountStore;
    uint256 numAccounts = 0;

    constructor() {
        owner = msg.sender;
        accountStore[msg.sender] = Account(
            true,
            numAccounts,
            AccountType.ADMIN
        );
        numAccounts++;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAdmin() {
        require(accountStore[msg.sender].accountType == AccountType.ADMIN);
        _;
    }

    modifier isUser(address address_) {
        require(accountStore[address_].accountType == AccountType.USER);
        _;
    }

    modifier isModerator(address address_) {
        require(accountStore[address_].accountType == AccountType.MODERATOR);
        _;
    }

    modifier isNotAdmin(address address_) {
        require(accountStore[address_].accountType != AccountType.ADMIN);
        _;
    }

    function registerAccount() public {
        accountStore[msg.sender] = Account(true, numAccounts, AccountType.USER);
        numAccounts++;
    }

    function addAccount(address address_) public onlyAdmin {
        accountStore[address_] = Account(true, numAccounts, AccountType.USER);
        numAccounts++;
    }

    function setUser(address address_) public onlyAdmin isNotAdmin(address_) {
        accountStore[address_].accountType = AccountType.USER;
    }

    function setModerator(
        address address_
    ) public onlyAdmin isNotAdmin(address_) {
        accountStore[address_].accountType = AccountType.MODERATOR;
    }

    function setAdmin(address address_) public onlyOwner isNotAdmin(address_) {
        accountStore[address_].accountType = AccountType.ADMIN;
    }

    function setActive(address address_) public onlyAdmin {
        accountStore[address_].isActive = true;
    }

    function setInactive(address address_) public onlyAdmin isUser(address_) {
        accountStore[address_].isActive = false;
    }

    function getAccountType(
        address address_
    ) public view returns (AccountType) {
        return accountStore[address_].accountType;
    }

    function getAccountActive(address address_) public view returns (bool) {
        return accountStore[address_].isActive;
    }
}
