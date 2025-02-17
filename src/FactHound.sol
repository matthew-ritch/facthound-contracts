// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title FactHound
/// @notice A decentralized information bounty platform
contract FactHound {
    // --- Custom Errors ---
    error QuestionResolved();
    error QuestionCancelled();
    error QuestionExists();
    error AnswerExists();
    error AnswerNotExists();
    error NotAuthorized();
    error NoFeesToWithdraw();

    // --- State Variables ---
    address public owner;
    uint16 public immutable asker_fee_per_10000;
    uint256 public total_bounty;

    // --- Enums ---
    enum QuestionStatus {
        OPEN, // 0: open
        RESOLVED, // 1: answer selected + payout resolved
        CANCELLED // 2: cancelled
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
    event AnswerRedeemed(
        bytes32 indexed _questionHash,
        bytes32 indexed _answerHash
    );

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier notCancelled(bytes32 questionHash) {
        if (getQuestion[questionHash].status == QuestionStatus.CANCELLED)
            revert QuestionCancelled();
        _;
    }

    modifier notResolved(bytes32 questionHash) {
        if (getQuestion[questionHash].status == QuestionStatus.RESOLVED)
            revert QuestionResolved();
        _;
    }

    // --- Constructor ---
    constructor(uint16 _asker_fee_per_10000) {
        owner = msg.sender;
        asker_fee_per_10000 = _asker_fee_per_10000;
    }

    // --- External/Public Functions ---

    /**
     * @notice Creates a new question.
     * @param questionHash is keccak256(abi.encodePacked(askerAddress, questionString));
     */
    function createQuestion(bytes32 questionHash) external payable {
        if (getQuestion[questionHash].asker != address(0))
            revert QuestionExists();
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
        if (getAnswerer[questionHash][answerHash] != address(0))
            revert AnswerExists();
        getAnswerer[questionHash][answerHash] = payable(msg.sender);
        emit AnswerCreated(msg.sender, questionHash, answerHash);
    }

    /**
     * @notice selects the answer any pays out the bounty
     */
    function selectAnswer(
        bytes32 questionHash,
        bytes32 answerHash
    ) external notCancelled(questionHash) notResolved(questionHash) {
        Question storage question = getQuestion[questionHash];
        if (getAnswerer[questionHash][answerHash] == address(0))
            revert AnswerNotExists();
        if (msg.sender != question.asker) revert NotAuthorized();
        question.selectedAnswer = answerHash;
        // redeem bounty
        uint256 bounty = question.bounty;
        unchecked {
            total_bounty -= bounty;
        }
        question.status = QuestionStatus.RESOLVED;
        getAnswerer[questionHash][answerHash].transfer(bounty);
        emit AnswerRedeemed(questionHash, answerHash);
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

    /**
     * @notice Gets the address that answered a question
     * @param questionHash the question
     * @param answerHash the answer
     * @return address of the answerer
     */
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
        if (_owner == address(0)) revert NotAuthorized();
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
