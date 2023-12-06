// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

contract TrustScore {
    address public owner;
    mapping(address => uint256) approvedAddresses;
    uint256 public defaultTrustScore;
    Range public defaultRange = Range(0, 500);

    struct Range {
        // inclusive
        uint256 floor;
        uint256 ceil;
    }

    enum TrustTier {
        HIGHLYTRUSTED, // 450-500
        TRUSTED, // 300-449
        NEUTRAL, // 200-299
        UNTRUSTED // 0-199
    }

    mapping(TrustTier => Range) tierSystem;
    mapping(TrustTier => uint256) contractCompletionReward;

    struct Trust {
        bool isValid;
        uint256 score;
        TrustTier tier;
    }

    mapping(address => Trust) trustStore;

    constructor(uint256 defaultTrustScore_) {
        owner = msg.sender;
        approvedAddresses[msg.sender] = 1;
        defaultTrustScore = defaultTrustScore_;

        tierSystem[TrustTier.HIGHLYTRUSTED] = Range(450, 500);
        tierSystem[TrustTier.TRUSTED] = Range(300, 449);
        tierSystem[TrustTier.NEUTRAL] = Range(200, 299);
        tierSystem[TrustTier.UNTRUSTED] = Range(0, 199);

        contractCompletionReward[TrustTier.HIGHLYTRUSTED] = 1;
        contractCompletionReward[TrustTier.TRUSTED] = 5;
        contractCompletionReward[TrustTier.NEUTRAL] = 10;
        contractCompletionReward[TrustTier.UNTRUSTED] = 15;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner!");
        _;
    }

    modifier onlyApproved() {
        require(approvedAddresses[msg.sender] == 1, "User not approved!");
        _;
    }

    modifier outOfRange(uint256 score) {
        require(
            score <= defaultRange.ceil && score >= defaultRange.floor,
            "Out of default range"
        );
        _;
    }

    function approveAddress(address address_) public onlyOwner {
        approvedAddresses[address_] = 1;
    }

    function setDefaultTrustScore(
        uint256 score
    ) public onlyApproved outOfRange(score) {
        defaultTrustScore = score;
    }

    function setTrustScore(
        address address_,
        uint256 score
    ) public onlyApproved outOfRange(score) {
        Trust memory trust;
        trust.score = score;

        if (score <= 199) {
            trust.tier = TrustTier.UNTRUSTED;
        } else if (score <= 299) {
            trust.tier = TrustTier.NEUTRAL;
        } else if (score <= 449) {
            trust.tier = TrustTier.TRUSTED;
        } else if (score <= 500) {
            trust.tier = TrustTier.HIGHLYTRUSTED;
        }

        trust.isValid = true;
        trustStore[address_] = trust;
    }

    function increaseTrustScore(
        address address_,
        uint256 amount
    ) public onlyApproved {
        require(trustStore[address_].isValid);

        uint256 newScore = getTrustScore(address_) + amount;
        if (newScore > 500) {
            newScore = 500;
        }

        setTrustScore(address_, newScore);
    }

    function decreaseTrustScore(
        address address_,
        uint256 amount
    ) public onlyApproved {
        require(trustStore[address_].isValid);

        uint256 newScore = 0;
        if (amount < getTrustScore(address_)) {
            newScore = getTrustScore(address_) - amount;
        }

        setTrustScore(address_, newScore);
    }

    function getTrustScore(
        address address_
    ) public view onlyApproved returns (uint256) {
        return trustStore[address_].score;
    }

    function getTrustTier(
        address address_
    ) public view onlyApproved returns (TrustTier) {
        return trustStore[address_].tier;
    }
}
