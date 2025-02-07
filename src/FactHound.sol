// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title FactHound
/// @notice A decentralized information bounty platform
contract FactHound {
    // --- Custom Errors ---
    error NotOwner();
    error NotOracle();
    error QuestionResolved();
    error QuestionCancelled();
    error QuestionExists();
    error AnswerExists();
    error AnswerNotExists();
    error NotAuthorized();
    error NoAnswerSelected();
    error InvalidOwner();
    error NoFeesToWithdraw();

    // --- State Variables ---
    address public owner;
    address public immutable oracle;
    uint16 public immutable asker_fee_per_10000;
    
    uint256 public total_bounty;

    // --- Enums ---
    enum QuestionStatus {
        OPEN,          // 0: open
        SELECTED,      // 1: answer selected
        REJECTED,      // 2: answer selected by asker was rejected by oracle
        RESOLVED,      // 3: resolved
        CANCELLED      // 4: cancelled
    }

    // --- Structs ---
    struct Question {
        address asker;
        uint128 bounty;
        bytes32 selectedAnswer;
        QuestionStatus status;
    }

    // --- Mappings ---
    mapping(bytes32 => Question) public getQuestion; // questionHash -> Question
    mapping(bytes32 => mapping(bytes32 => address payable)) public getAnswerer; // questionHash -> (answerHash -> answerer)

    // --- Events ---
    event QuestionCreated(
        address indexed _asker,
        bytes32 indexed _questionHash,
        uint _bounty
    );
    event AnswerCreated(
        address indexed _answerer,
        bytes32 indexed _questionHash,
        bytes32 indexed _answerHash
    );
    event AnswerSelected(
        bytes32 indexed _questionHash,
        bytes32 indexed _answerHash
    );
    event AnswerRejected(
        bytes32 indexed _questionHash,
        bytes32 indexed _answerHash
    );
    event AnswerRedeemed(
        bytes32 indexed _questionHash,
        bytes32 indexed _answerHash
    );

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOracle() {
        if (msg.sender != oracle) revert NotOracle();
        _;
    }

    modifier notResolved(bytes32 questionHash) {
        if (getQuestion[questionHash].status == QuestionStatus.RESOLVED) revert QuestionResolved();
        _;
    }

    modifier notCancelled(bytes32 questionHash) {
        if (getQuestion[questionHash].status == QuestionStatus.CANCELLED) revert QuestionCancelled();
        _;
    }

    // --- Constructor ---
    constructor(address _oracle, uint16 _asker_fee_per_10000) {
        owner = msg.sender;
        oracle = _oracle;
        asker_fee_per_10000 = _asker_fee_per_10000;
    }

    // --- External/Public Functions ---
    
    /**
     * @notice Creates a new question.
     * @param questionHash is keccak256(abi.encodePacked(askerAddress, questionString));
     */
    function createQuestion(bytes32 questionHash) external payable {
        if (getQuestion[questionHash].asker != address(0)) revert QuestionExists();
        
        // calculate bounty fees
        uint256 fee;
        uint256 bounty;
        unchecked {
            fee = (msg.value * asker_fee_per_10000) / 10000;
            bounty = msg.value - fee;
            total_bounty += bounty;
        }

        Question storage question = getQuestion[questionHash];
        question.asker = msg.sender;
        question.bounty = uint128(bounty);
        question.status = QuestionStatus.OPEN;

        emit QuestionCreated(msg.sender, questionHash, bounty);
    }

    /**
     * @notice Creates a new answer for a question
     * @param questionHash The hash of the question being answered
     * @param answerHash keccak256(abi.encodePacked(answererAddress, answerString))
     */
    function createAnswer(
        bytes32 questionHash,
        bytes32 answerHash
    ) external notCancelled(questionHash) {
        if (getAnswerer[questionHash][answerHash] != address(0)) revert AnswerExists();
        
        getAnswerer[questionHash][answerHash] = payable(msg.sender);
        emit AnswerCreated(msg.sender, questionHash, answerHash);
    }

    /**
     * @notice selects the answer to be certified by the oracle
     */
    function selectAnswer(
        bytes32 questionHash,
        bytes32 answerHash
    ) external notCancelled(questionHash) {
        Question storage question = getQuestion[questionHash];
        if (getAnswerer[questionHash][answerHash] == address(0)) revert AnswerNotExists();
        
        if (question.status == QuestionStatus.REJECTED) {
            if (msg.sender != oracle) revert NotAuthorized();
        } else {
            if (msg.sender != oracle && msg.sender != question.asker) revert NotAuthorized();
        }
        
        question.selectedAnswer = answerHash;
        question.status = QuestionStatus.SELECTED;
        emit AnswerSelected(questionHash, answerHash);
    }

    /**
     * @notice certifies the selected answer and pays out bounty
     */
    function redeemAnswer(
        bytes32 questionHash
    ) external onlyOracle notCancelled(questionHash) notResolved(questionHash) {
        Question storage question = getQuestion[questionHash];
        bytes32 selectedAnswer = question.selectedAnswer;
        if (selectedAnswer == 0) revert NoAnswerSelected();

        uint256 bounty = question.bounty;
        unchecked {
            total_bounty -= bounty;
        }
        
        question.status = QuestionStatus.RESOLVED;
        getAnswerer[questionHash][selectedAnswer].transfer(bounty);
        
        emit AnswerRedeemed(questionHash, selectedAnswer);
    }

    /**
     * @notice rejects the selected answer
     */
    function rejectAnswer(
        bytes32 questionHash
    ) external onlyOracle notCancelled(questionHash) notResolved(questionHash) {
        Question storage question = getQuestion[questionHash];
        require(question.selectedAnswer != 0, "No answer selected");
        question.status = QuestionStatus.REJECTED; // mark as rejected
        //
        emit AnswerRejected(questionHash, question.selectedAnswer);
    }

    /**
     * @notice cancels the question and returns bounty to asker
     */
    function cancelQuestion(
        bytes32 questionHash
    ) external onlyOwner notCancelled(questionHash) notResolved(questionHash) {
        Question storage question = getQuestion[questionHash];
        question.status = QuestionStatus.CANCELLED; // mark as cancelled
        total_bounty -= question.bounty;
        payable(question.asker).transfer(question.bounty);
    }

    // --- View Functions ---
    function getAnswererAddress(
        bytes32 questionHash,
        bytes32 answerHash
    ) external view returns (address) {
        return getAnswerer[questionHash][answerHash];
    }

    // --- Administrative Functions ---
    
    /**
     * @notice Updates the owner of the contract
     * @param _owner The new owner address
     */
    function setOwner(address _owner) external onlyOwner {
        if (_owner == address(0)) revert InvalidOwner();
        owner = _owner;
    }

    /**
     * @notice Withdraws accumulated fees from the contract
     */
    function withdraw() external onlyOwner {
        uint256 withdrawAmount;
        unchecked {
            withdrawAmount = address(this).balance - total_bounty;
        }
        if (withdrawAmount == 0) revert NoFeesToWithdraw();
        payable(msg.sender).transfer(withdrawAmount);
    }
}
