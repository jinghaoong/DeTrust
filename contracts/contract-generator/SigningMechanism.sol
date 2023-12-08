// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ContractUtility.sol";
import "./BaseContract.sol";

contract SigningMechanism {

    BaseContract base;

    event ContractSigned(uint256 indexed _contractId, address indexed _signer);

    modifier notFreeze(uint256 _contractId) {
        require(base.isActive(_contractId), "The contract is inactivated!");
        _;
    }

    modifier onlyInvolved(uint256 _contractId) {
        require(base.isInvolved(_contractId, msg.sender), 
            "You are not involved in the contract!");
        _;
    }

    constructor(BaseContract _base) {
        base = _base;
    }

    // get message hash for signing
    function getMessageHash(address _signer, uint256 _contractId, uint _nonce, 
        uint8 _v, bytes calldata _r, bytes calldata  _s) public pure returns (bytes32) {
        
        return keccak256(abi.encodePacked(_signer, 
            keccak256(abi.encodePacked(_contractId,
            keccak256(abi.encodePacked('VERIFY')), 
            keccak256(abi.encodePacked(_v, _r, _s)), _nonce))));
    }

    // sign the contract with message hash
    function sign(uint256 _contractId, uint _nonce, uint8 _v, bytes calldata _r, bytes calldata _s) 
        public onlyInvolved(_contractId) notFreeze(_contractId) {

        bytes32 messageHash = getMessageHash(msg.sender, _contractId, _nonce, _v, _r, _s);

        ContractUtility.BasicProperties memory properties = base.getGeneralRepo(_contractId);
        
        if (msg.sender == properties.signature.payer) {
            require(properties.signature._ad1 == bytes32(0), 
                "You have already signed this contract!");
            properties.signature._ad1 = messageHash;

        } else {
            require(properties.signature._ad2 == bytes32(0), 
                "You have already signed this contract!");
            properties.signature._ad2 = messageHash;
        
        }

        properties.signature.isSigned = properties.signature.isSigned + 1;

        if (properties.signature.isSigned == 2) {
            properties.state = ContractUtility.ContractState.SIGNED;
            properties.verificationStart = block.timestamp;
        }

        base.setGeneralRepo(_contractId, properties);

        emit ContractSigned(_contractId, msg.sender);
    }

    // verify the signature of the contract
    // need to be verify if there is a dispute only
    function verifySignature(address _signer, uint256 _contractId, uint _nonce, 
        uint8 _v, bytes calldata _r, bytes calldata _s) public view returns (bool) {

        bytes32 messageHash = getMessageHash(_signer, _contractId, _nonce, _v, _r, _s);

        ContractUtility.BasicProperties memory properties = base.getGeneralRepo(_contractId);

        if (_signer == properties.signature.payer) {
            return properties.signature._ad1 == messageHash;
        } else {
            return properties.signature._ad2 == messageHash;
        }

    }
}