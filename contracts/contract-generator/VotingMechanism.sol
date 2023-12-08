// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ContractUtility.sol";
import "./BaseContract.sol";
import "../DeTrustToken.sol";
import "../TrustScore.sol";

contract VotingMechanism {
    using SafeMath for uint256;

    BaseContract base;
    DeTrustToken deTrustToken;
    TrustScore trustScore;

    address owner;
    uint256 minimumTimeFrame = 1 days;
    uint256 verificationCutOffTime = 2 days;

    constructor(BaseContract _base, DeTrustToken _deTrustToken, TrustScore _trustScore) {
        base = _base;
        deTrustToken = _deTrustToken;
        trustScore = _trustScore;
        owner = msg.sender;
    }

    mapping(uint256 => address[]) contractVerifyList;
    mapping(uint256 => address[]) contractFraudList;

    event ContractVerified(uint256 indexed _contractId, address indexed _verifier, ContractUtility.VerificationState state);
    event VerificationResolved(uint256 indexed _contractId, ContractUtility.VerificationState _vstate);
    event PassedVerification(uint256 _contractId);
    event FailedVerification(uint256 _contractId);
    event UpdateMinTimeFrame(uint256 _minTime);
    event UpdateVerificationMaxTime(uint256 _maxTime);
    event UpdateTimeRange(uint256 _minTime, uint256 _maxTime);

    modifier isSigned(uint256 _contractId) {
        require(base.isSigned(_contractId), "Contract is not completely signed yet!");
        _;
    }

    modifier notFreeze(uint256 _contractId) {
        require(base.isActive(_contractId), "The contract is inactivated!");
        _;
    }

    modifier ownerOnly() {
        require(msg.sender == owner, "You are not the owner!");
        _;
    }

    // verification functions

    modifier verifyAllowed(uint256 _contractId) {

        ContractUtility.BasicProperties memory properties = base.getGeneralRepo(_contractId);

        require(properties.isVerified == ContractUtility.VerificationState.PENDING, 
            "Contract is already verified!");

        require(trustScore.getTrustTier(msg.sender) != TrustScore.TrustTier.UNTRUSTED, 
            "You are not qualified to verify a contract!");
        
        require(block.timestamp - properties.verificationStart <= verificationCutOffTime, 
                "Verification time is over!");

        require(trustScore.getTrustTier(msg.sender) != TrustScore.TrustTier.UNTRUSTED, 
            "You are not qualified to verify a contract!");
        
        unchecked {
            require(block.timestamp - properties.verificationStart <= verificationCutOffTime, 
                "Verification time is over!");

            bool verifierExceeded1 = block.timestamp - properties.verificationStart > minimumTimeFrame && 
                    properties.legitAmount.add(properties.fraudAmount) < properties.verifierNeeded;
            
            bool verifierExceeded2 = block.timestamp - properties.verificationStart <= minimumTimeFrame &&
                    properties.legitAmount.add(properties.fraudAmount) < properties.verifierNeeded * 2;

            require(verifierExceeded1 || verifierExceeded2, "Verifier amount exceeded!");
        }
        _;
    }

    modifier verificationCanBeResolved(uint256 _contractId) {
        ContractUtility.BasicProperties memory properties = base.getGeneralRepo(_contractId);

        require(properties.isVerified == ContractUtility.VerificationState.PENDING, 
            "Contract is not available for verification!");

        require(block.timestamp - properties.verificationStart > verificationCutOffTime ||
            (block.timestamp - properties.verificationStart > minimumTimeFrame &&
            (properties.legitAmount >= properties.verifierNeeded / 2)), 
            "Resolve is not available yet!");
            
        _;
    }

    // verifier should not be involved in the contract
    modifier notInvolved(uint256 _contractId, address _wallet) {
        bool checkVoted = false;

        for (uint256 i = 0; i < contractVerifyList[_contractId].length; i++) {
            if (contractVerifyList[_contractId][i] == msg.sender) {
                require(checkVoted, "You have voted for this contract!");
            }
        }

        for (uint256 i = 0; i < contractFraudList[_contractId].length; i++) {
            if (contractFraudList[_contractId][i] == msg.sender) {
                require(checkVoted, "You have voted for this contract!");
            }
        }

        require(msg.sender != base.getGeneralRepo(_contractId).signature.payer && 
            msg.sender != base.getGeneralRepo(_contractId).signature.payee, 
            "You are involved in this contract!");

        if (base.getGeneralRepo(_contractId).contractType == ContractUtility.ContractType.COMMON) {
            CommonContract common = CommonContract(base.getAddressRepo(_contractId));
            require(!common.isPayer(msg.sender) && !common.isPayee(msg.sender), 
                "You are involved in this contract!");

        }

        require(trustScore.getTrustTier(msg.sender) != TrustScore.TrustTier.UNTRUSTED, 
            "Insufficient trust score!");
        require(deTrustToken.balanceOf(_wallet) >= 5, "Insufficient token to vote!");
        _;
    }

    // verify the contract
    // contract can be verified by any address except involvers
    function verifyContract(uint256 _contractId, ContractUtility.VerificationState _vstate, 
        address _wallet) public notFreeze(_contractId) isSigned(_contractId) verifyAllowed(_contractId) 
        notInvolved(_contractId, _wallet) returns (ContractUtility.VerificationState) {

        require(_vstate != ContractUtility.VerificationState.PENDING, "Invalid verification option!");
        
        base.setWalletMapping(msg.sender, _wallet);

        ContractUtility.BasicProperties memory properties = base.getGeneralRepo(_contractId);
        
        if(_vstate == ContractUtility.VerificationState.LEGITIMATE) {
            contractVerifyList[_contractId].push(msg.sender);
            properties.legitAmount = properties.legitAmount.add(1);
        } else {
            contractFraudList[_contractId].push(msg.sender);
            properties.fraudAmount = properties.fraudAmount.add(1);
        }

        base.setGeneralRepo(_contractId, properties);

        deTrustToken.transferFrom(address(base), _wallet, 10);

        emit ContractVerified(_contractId, msg.sender, _vstate);

        if (block.timestamp - properties.verificationStart > minimumTimeFrame) {
            if (properties.legitAmount >= properties.verifierNeeded / 2) {
                properties.isVerified = ContractUtility.VerificationState.LEGITIMATE;
                base.setGeneralRepo(_contractId, properties);
                emit PassedVerification(_contractId);
                return ContractUtility.VerificationState.LEGITIMATE;

            } else if (properties.fraudAmount >= properties.verifierNeeded / 2) {
                properties.isVerified = ContractUtility.VerificationState.FRAUDULENT;
                base.setGeneralRepo(_contractId, properties);
                emit FailedVerification(_contractId);
                return ContractUtility.VerificationState.FRAUDULENT;
            }
        }
        
        return ContractUtility.VerificationState.PENDING;
    }

    function resolveVerification(uint256 _contractId) public notFreeze(_contractId) 
        isSigned(_contractId) verificationCanBeResolved(_contractId) {

        ContractUtility.BasicProperties memory properties = base.getGeneralRepo(_contractId);

        if (properties.isVerified == ContractUtility.VerificationState.PENDING) {
            if (properties.legitAmount >= properties.fraudAmount) {
                properties.isVerified = ContractUtility.VerificationState.LEGITIMATE;
                emit PassedVerification(_contractId);
            } else {
                properties.isVerified = ContractUtility.VerificationState.FRAUDULENT;
                emit FailedVerification(_contractId);
            }
        }

        base.setGeneralRepo(_contractId, properties);

        if (properties.isVerified == ContractUtility.VerificationState.LEGITIMATE) {
            base.proceedContract(_contractId);

            for (uint256 i = 0; i < contractFraudList[_contractId].length; i++) {
                deTrustToken.burnFor(base.getWalletAddress(contractFraudList[_contractId][i]), 100);
                trustScore.decreaseTrustScore(contractFraudList[_contractId][i], 1);
            }
            
        } else {
            base.voidContract(_contractId);
            
            deTrustToken.burnFor(base.getWalletAddress(properties.signature.payer), 500);
            deTrustToken.burnFor(base.getWalletAddress(properties.signature.payee), 500);
            trustScore.decreaseTrustScore(properties.signature.payer, 2);
            trustScore.decreaseTrustScore(properties.signature.payee, 2);

            for (uint256 i = 0; i < contractVerifyList[_contractId].length; i++) {
                deTrustToken.burnFor(base.getWalletAddress(contractVerifyList[_contractId][i]), 100);
                trustScore.decreaseTrustScore(contractVerifyList[_contractId][i], 1);
            }

        }

        emit VerificationResolved(_contractId, properties.isVerified);
    }

    function setMinimumTimeFrame(uint256 _newMin) public ownerOnly {
        require(_newMin < verificationCutOffTime, "The min time is longer than the cutoff time!");
        minimumTimeFrame = _newMin; 
        emit UpdateMinTimeFrame(_newMin);
    }

    function setVerificationCutOffTime(uint256 _newMax) public ownerOnly {
        require(_newMax > minimumTimeFrame, "The max time is shorter than the min time!");
        verificationCutOffTime = _newMax;
        emit UpdateVerificationMaxTime(_newMax);
    }

    function setTimeRange(uint256 _min, uint256 _max) public ownerOnly {
        require(_min < _max, "Invalid time range!");
        minimumTimeFrame = _min;
        verificationCutOffTime = _max;
        emit UpdateTimeRange(_min, _max);
    }
}