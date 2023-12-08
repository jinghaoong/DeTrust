// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ContractUtility.sol";
import "./BaseContract.sol";

contract CommunicationChannel {

    BaseContract base;

    mapping(uint256 => string[]) messageLog;

    event MessageSent(uint256 indexed _contractId, address indexed _sender, string _message);

    constructor(BaseContract _base) {
        base = _base;
    }

    modifier notFreeze(uint256 _contractId) {
        require(base.isActive(_contractId), "The contract is inactivated!");
        _;
    }

    modifier onlyInvolved(uint256 _contractId) {
        require(base.isInvolved(_contractId, msg.sender), 
            "You are not involved in the contract!");
        _;
    }

    // chat communication functions

    // involvers (initiator and respondent in the case of common contract) can send message to each other
    function sendMessage(uint256 _contractId, string memory _message) 
        public onlyInvolved(_contractId) notFreeze(_contractId) {
        
        // label each message string with the sender
        if (msg.sender == base.getGeneralRepo(_contractId).signature.payer) {
            messageLog[_contractId].push(string(abi.encodePacked('Payer', ': ', _message)));
        } else {
            messageLog[_contractId].push(string(abi.encodePacked('Payee', ': ', _message)));
        }

        emit MessageSent(_contractId, msg.sender, _message);
        
    }

    // get all messages in the message log for a certain contract by invlovers only
    function retrieveMessage(uint256 _contractId) public view 
        onlyInvolved(_contractId) returns (string memory) {
        string memory messages = "";

        // concatenate all messages in the message log
        for (uint i = 0; i < messageLog[_contractId].length; i++) {
            messages = string(abi.encodePacked(messages, messageLog[_contractId][i], '\n'));
        }

        return messages;
    }

}