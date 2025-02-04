// SPDX-License-Identifier: MIT
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
    bool public isCancelled;

    mapping(bytes32 => address payable) public answerInfoMap; // answerHash -> answerer address

    event AnswerCreated(address indexed _answerer, bytes32 indexed _answerHash);
    event AnswerSelected(bytes32 indexed _answerHash);
    event AnswerCertified(bytes32 indexed _answerHash);
    event AnswerRejected(bytes32 indexed _answerHash);
    event AnswerRedeemed(bytes32 indexed _answerHash);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle);
        _;
    }

    modifier notResolved() {
        require(!isResolved);
        _;
    }
    modifier notCancelled() {
        require(!isCancelled);
        _;
    }

    constructor(
        address _owner,
        address _oracle,
        address _asker,
        bytes32 _questionHash
    ) payable {
        owner = _owner;
        oracle = _oracle;
        asker = _asker;
        questionHash = _questionHash;
        selectedAnswer = 0;
        isCertified = false;
        askerSelectionRejected = false;
    }

    /**
     * @notice Creates a new answer for this question. answerHash is keccak256(abi.encodePacked(answererAddress, answerString));
     */
    function createAnswer(bytes32 answerHash) public notCancelled {
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
    function selectAnswer(bytes32 answerHash) public notCancelled notResolved {
        // allows either the asker or the oracle to select an answer, unless the asker's selection has already been rejected.
        if (askerSelectionRejected) {
            require(msg.sender == oracle);
        } else {
            require((msg.sender == oracle) || (msg.sender == asker));
        }
        // if answerHash does not exist revert. check answerInfoMap
        require(
            answerInfoMap[answerHash] != address(0),
            "Answer not in answerInfoMap"
        );
        // set selectedAnswer to answerHash
        selectedAnswer = answerHash;
        //
        emit AnswerSelected(answerHash);
    }

    function _certifyAnswer() internal onlyOracle notCancelled notResolved {
        // ensure selectedAnswer is nonzero
        require(selectedAnswer != 0);
        //
        isCertified = true;
        //
        emit AnswerCertified(selectedAnswer);
    }

    /**
     * @notice certifies the selected answer. enables payout trigger
     * restricted to oracle.
     */
    function certifyAnswer() public onlyOracle notCancelled notResolved {
        _certifyAnswer();
    }

    /**
     * @notice trigger payout to the selected answerer.
     * restricted to oracle
     * enabled by _certifyAnswer
     */
    function _redeemBounty() internal onlyOracle notCancelled notResolved {
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
     * @notice reject the selected answer. disable payout trigger.
     * restricted to oracle.
     */
    function rejectAnswer() public onlyOracle notCancelled notResolved {
        // ensure selectedAnswer is nonzero
        require(selectedAnswer != 0);
        //
        isCertified = false;
        askerSelectionRejected = true;
        //
        emit AnswerRejected(selectedAnswer);
    }

    /**
     * @notice trigger payout to the selected answerer.
     * restricted to oracle
     * enabled by certifyAnswer
     */
    function redeemBounty() public onlyOracle notCancelled notResolved {
        _redeemBounty();
    }

    /**
     * @notice trigger payout to the selected answerer.
     * restricted to oracle
     * enabled by certifyAnswer
     */
    function certifyAndRedeemAnswer() public onlyOracle notCancelled notResolved {
        _certifyAnswer();
        _redeemBounty();
    }


    /**
     * @notice cancel this question. return bounty to answer
     * restricted to owner
     */
    function cancel() public onlyOwner notCancelled notResolved {
        // set to cancelled
        isCancelled = true;
        // return bounty to asker
        payable(asker).transfer(address(this).balance);
    }
}
