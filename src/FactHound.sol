// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title FactHound
/// @notice A decentralized Q&A platform with oracle verification
contract FactHound {
    // --- State Variables ---
    // Administrative
    address public owner;
    address public oracle;
    uint16 public asker_fee_per_10000;
    
    // Financial tracking
    uint public total_bounty;

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
        uint bounty;
        bytes32 selectedAnswer;
        QuestionStatus status;
        mapping(bytes32 => address payable) answerMap; // answerHash -> answerer address
    }

    // --- Mappings ---
    mapping(bytes32 => Question) public getQuestion; // questionHash -> Question

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
        require(msg.sender == owner, "FactHound: caller is not owner");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "FactHound: caller is not oracle");
        _;
    }

    modifier notResolved(bytes32 questionHash) {
        require(getQuestion[questionHash].status != QuestionStatus.RESOLVED, "FactHound: question already resolved");
        _;
    }

    modifier notCancelled(bytes32 questionHash) {
        require(getQuestion[questionHash].status != QuestionStatus.CANCELLED, "FactHound: question is cancelled");
        _;
    }

    // --- Constructor ---
    constructor(address _oracle, uint16 _asker_fee_per_10000) {
        owner = msg.sender;
        oracle = _oracle;
        asker_fee_per_10000 = _asker_fee_per_10000;
        total_bounty = 0;
    }

    // --- External/Public Functions ---
    
    /**
     * @notice Creates a new question.
     * @param questionHash is keccak256(abi.encodePacked(askerAddress, questionString));
     */
    function createQuestion(bytes32 questionHash) external payable {
        require(
            getQuestion[questionHash].asker == address(0),
            "Question Already Exists"
        );
        // calculate bounty fees
        uint fee = (msg.value / 10000) * asker_fee_per_10000; //rounds down
        uint bounty = msg.value - fee;
        // create question
        Question storage question = getQuestion[questionHash];
        question.asker = msg.sender;
        question.bounty = bounty;
        question.selectedAnswer = 0;
        question.status = QuestionStatus.OPEN;
        //
        emit QuestionCreated(msg.sender, questionHash, bounty);
        //
        total_bounty += bounty;
    }

    /**
     * @notice Creates a new answer for a question
     * @param questionHash The hash of the question being answered
     * @param answerHash keccak256(abi.encodePacked(answererAddress, answerString))
     */
    function createAnswer(
        bytes32 questionHash,
        bytes32 answerHash
    ) public notCancelled(questionHash) {
        require(
            getQuestion[questionHash].answerMap[answerHash] == address(0),
            "FactHound: answer already exists"
        );
        
        getQuestion[questionHash].answerMap[answerHash] = payable(msg.sender);
        emit AnswerCreated(msg.sender, questionHash, answerHash);
    }

    /**
     * @notice selects the answer to be certified by the oracle
     */
    function selectAnswer(
        bytes32 questionHash,
        bytes32 answerHash
    ) public notCancelled(questionHash) {
        Question storage question = getQuestion[questionHash];
        // check if answer exists
        require(
            question.answerMap[answerHash] != address(0),
            "Answer does not exist"
        );
        // check if caller is oracle or asker (if answer not previously rejected)
        if (question.status == QuestionStatus.REJECTED) {
            require(
                msg.sender == oracle,
                "Only oracle can select after rejection"
            );
        } else {
            require(
                msg.sender == oracle || msg.sender == question.asker,
                "Not authorized"
            );
        }
        question.selectedAnswer = answerHash;
        //
        emit AnswerSelected(questionHash, answerHash);
    }

    /**
     * @notice certifies the selected answer and pays out bounty
     */
    function redeemAnswer(
        bytes32 questionHash
    ) public onlyOracle notCancelled(questionHash) notResolved(questionHash) {
        Question storage question = getQuestion[questionHash];
        require(question.selectedAnswer != 0, "No answer selected");
        question.status = QuestionStatus.RESOLVED;
        // transfer bounty to answerer
        address payable answerer = question.answerMap[question.selectedAnswer];
        total_bounty -= question.bounty;
        answerer.transfer(question.bounty);
        //
        emit AnswerRedeemed(questionHash, question.selectedAnswer);
    }

    /**
     * @notice rejects the selected answer
     */
    function rejectAnswer(
        bytes32 questionHash
    ) public onlyOracle notCancelled(questionHash) notResolved(questionHash) {
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
    ) public onlyOwner notCancelled(questionHash) notResolved(questionHash) {
        Question storage question = getQuestion[questionHash];
        question.status = QuestionStatus.CANCELLED; // mark as cancelled
        total_bounty -= question.bounty;
        payable(question.asker).transfer(question.bounty);
    }

    // --- Administrative Functions ---
    
    /**
     * @notice Updates the owner of the contract
     * @param _owner The new owner address
     */
    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "FactHound: invalid owner address");
        owner = _owner;
    }

    /**
     * @notice Withdraws accumulated fees from the contract
     */
    function withdraw() external onlyOwner {
        uint256 withdrawAmount = address(this).balance - total_bounty;
        require(withdrawAmount > 0, "FactHound: no fees to withdraw");
        payable(msg.sender).transfer(withdrawAmount);
    }
}
