// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Question.sol";

contract QuestionFactory {
    address public owner;
    address public oracle;
    uint8 public asker_fee_per_10000;
    mapping(bytes32 => address) public getQuestion;

    event QuestionCreated(
        address indexed _asker,
        bytes32 indexed _questionHash,
        uint _bounty
    );

    constructor(address _oracle, uint8 _asker_fee_per_10000) {
        owner = msg.sender;
        oracle = _oracle;
        asker_fee_per_10000 = _asker_fee_per_10000;
    }

    /**
     * @notice Creates a new question.
     * @param questionHash is keccak256(abi.encodePacked(askerAddress, questionString));
     */
    function createQuestion(bytes32 questionHash) external payable {
        require(
            getQuestion[questionHash] == address(0),
            "Question Already Exists"
        );
        // calculate bounty fees
        uint bounty_before_fees = msg.value;
        uint fee = (bounty_before_fees / 10000) * asker_fee_per_10000; //rounds down
        // create question
        address payable questionAddress = payable(
            address(
                (new Question){value: bounty_before_fees - fee}(
                    owner,
                    oracle,
                    msg.sender,
                    questionHash
                )
            )
        );
        require(
            questionAddress.balance == bounty_before_fees - fee,
            "Bounty setup failed."
        );
        // add it to the getQuestion map
        getQuestion[questionHash] = questionAddress;
        //
        emit QuestionCreated(
            msg.sender,
            questionHash,
            bounty_before_fees - fee
        );
    }

    /**
     * @notice Updates the owner of the factory
     * @dev Must be called by the current owner
     * @param _owner The new owner of the factory
     */
    function setOwner(address _owner) external {
        require(msg.sender == owner);
        owner = _owner;
    }
}
