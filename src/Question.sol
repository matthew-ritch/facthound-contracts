// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Question {
    address public owner;
    address public oracle;
    address public asker;
    bytes32 public questionHash;
    bytes32 public selectedAnswer;
    bool public askerSelectionRejected;
    bool public isCertified;
    bool public isResolved;

    mapping(bytes32 => address payable) public answerInfoMap; // answerHash -> answerer address

    event AnswerCreated(address indexed _answerer, bytes32 indexed _answerHash);

    event AnswerSelected(bytes32 indexed _answerHash);

    event AnswerCertified(bytes32 indexed _answerHash);

    event AnswerRejected(bytes32 indexed _answerHash);

    event AnswerRedeemed(bytes32 indexed _answerHash);

    constructor(
        address _owner,
        address _oracle,
        address _asker,
        bytes32 _questionHash
    ) {
        owner = _owner;
        oracle = _oracle;
        asker = _asker;
        questionHash = _questionHash;
        selectedAnswer = 0;
        isCertified = false;
        askerSelectionRejected = false;
    }

    /**
     * @notice Creates a new answer for this question. answerHash is the keccak256 hash of string(answer)
     */
    function createAnswer(bytes32 answerHash) public {
        // if answerHash already exists revert. check answerInfoMap
        require(answerInfoMap[answerHash] == address(0));
        // add answerHash and msg.sender to answerInfoMap
        answerInfoMap[answerHash] = payable(msg.sender);
        //
        emit AnswerCreated(msg.sender, answerHash);
    }

    /**
     * @notice selects the answer to be certified by the oracle
     */
    function selectAnswer(bytes32 answerHash) public {
        // allows either the asker or the oracle to select an answer, unless the asker's selection has already been rejected.
        if (askerSelectionRejected) {
            require((msg.sender == oracle) || (msg.sender == asker));
        } else {
            require(msg.sender == oracle);
        }
        // if answerHash does not exist revert. check answerInfoMap
        require(answerInfoMap[answerHash] != address(0));
        // set selectedAnswer to answerHash
        selectedAnswer = answerHash;
        //
        emit AnswerSelected(answerHash);
    }

    /**
     * @notice certifies the selected answer. enable payout trigger
     * restricted to oracle.
     */
    function certifyAnswer() public {
        require(msg.sender == oracle);
        // ensure selectedAnswer is nonzero
        require(selectedAnswer != 0);
        isCertified = true;
        //
        emit AnswerCertified(selectedAnswer);
    }

    /**
     * @notice reject the selected answer. disable payout trigger.
     * restricted to oracle.
     */
    function rejectAnswer() public {
        require(msg.sender == oracle);
        isCertified = false;
        askerSelectionRejected = true;
        //
        emit AnswerRejected(selectedAnswer);
    }

    /**
     * @notice trigger payout to the selected answerer.
     * restricted to owner
     */
    function redeemBounty() public {
        require(msg.sender == owner);
        // ensure selectedAnswer is nonzero
        require(selectedAnswer != 0);
        // ensure isCertified is true
        require(isCertified);
        // pay out bounty to selectedAnswer
        answerInfoMap[selectedAnswer].transfer(address(this).balance);
        isResolved = true;
        //
        emit AnswerRedeemed(selectedAnswer);
    }

    /**
     * @notice cancel this question. return bounty to answer
     * restricted to owner
     */
    function cancel() public {
        require(msg.sender == owner);
        // return bounty to asker
        payable(asker).transfer(address(this).balance);
    }
}
