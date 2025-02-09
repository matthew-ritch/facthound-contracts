// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {FactHound} from "../src/FactHound.sol";

contract FactHoundTestCreateQuestion is Test {
    FactHound public factHound;
    address public owner;
    address public oracle;
    address public asker;
    address public answerer;
    uint16 public asker_fee_per_10000;
    bytes32 questionHash;
    bytes32 answerHash;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer = vm.addr(4);
        asker_fee_per_10000 = 100;
        vm.prank(owner);
        factHound = new FactHound(oracle, asker_fee_per_10000);
    }

    function testCreateQuestion() public {
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        vm.deal(asker, 1 ether);
        vm.prank(asker);
        factHound.createQuestion{value: 1 ether}(questionHash);

        // Verify question created properly
        (
            address storedAsker,
            uint bounty,
            bytes32 selectedAnswer,
            FactHound.QuestionStatus status
        ) = factHound.getQuestion(questionHash);

        assertEq(storedAsker, asker);
        assertEq(bounty, 0.99 ether); // After 1% fee
        assertEq(selectedAnswer, bytes32(0));
        assertEq(uint(status), uint(FactHound.QuestionStatus.OPEN));
    }

    function testCreateQuestionRevertsIfAlreadyExists() public {
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        vm.deal(asker, 2 ether);
        vm.prank(asker);
        factHound.createQuestion{value: 1 ether}(questionHash);

        vm.expectRevert(FactHound.QuestionExists.selector);
        vm.prank(asker);
        factHound.createQuestion{value: 1 ether}(questionHash);
    }
}

contract FactHoundTestCreateAnswer is Test {
    FactHound public factHound;
    address public owner;
    address public oracle;
    address public asker;
    address public answerer1;
    address public answerer2;
    bytes32 questionHash;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);

        vm.prank(owner);
        factHound = new FactHound(oracle, 100);

        // Create question
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        vm.deal(asker, 1 ether);
        vm.prank(asker);
        factHound.createQuestion{value: 1 ether}(questionHash);
    }

    function testCreateAnswer() public {
        bytes32 answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        vm.prank(answerer1);
        factHound.createAnswer(questionHash, answerHash1);

        bytes32 answerHash2 = keccak256(
            abi.encodePacked(answerer2, "Yes, this is a test.")
        );
        vm.prank(answerer2);
        factHound.createAnswer(questionHash, answerHash2);
    }

    function testCreateAnswerRevertsIfAlreadyExists() public {
        bytes32 answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        vm.prank(answerer1);
        factHound.createAnswer(questionHash, answerHash1);

        vm.expectRevert(FactHound.AnswerExists.selector);
        vm.prank(answerer1);
        factHound.createAnswer(questionHash, answerHash1);
    }
}

contract FactHoundTestSelectAnswer is Test {
    FactHound public factHound;
    address public owner;
    address public oracle;
    address public asker;
    address public answerer1;
    address public answerer2;
    bytes32 questionHash;
    bytes32 answerHash1;
    bytes32 answerHash2;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);

        vm.prank(owner);
        factHound = new FactHound(oracle, 100);

        // Create question and answers
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        vm.deal(asker, 1 ether);
        vm.prank(asker);
        factHound.createQuestion{value: 1 ether}(questionHash);

        answerHash1 = keccak256(abi.encodePacked(answerer1, "No"));
        answerHash2 = keccak256(abi.encodePacked(answerer2, "Yes"));
        vm.prank(answerer1);
        factHound.createAnswer(questionHash, answerHash1);
        vm.prank(answerer2);
        factHound.createAnswer(questionHash, answerHash2);
    }

    function testSelectAnswerAsker() public {
        vm.prank(asker);
        factHound.selectAnswer(questionHash, answerHash2);

        (, , bytes32 selectedAnswer, ) = factHound.getQuestion(questionHash);
        assertEq(selectedAnswer, answerHash2);
    }

    function testSelectAnswerOracle() public {
        vm.prank(oracle);
        factHound.selectAnswer(questionHash, answerHash1);

        (, , bytes32 selectedAnswer, ) = factHound.getQuestion(questionHash);
        assertEq(selectedAnswer, answerHash1);
    }

    function testSelectAnswerRevertsIfNotAskerOrOracle() public {
        vm.expectRevert(FactHound.NotAuthorized.selector);
        vm.prank(answerer1);
        factHound.selectAnswer(questionHash, answerHash2);
    }
}

contract FactHoundTestRedeemAnswer is Test {
    FactHound public factHound;
    address public owner;
    address public oracle;
    address public asker;
    address public answerer;
    bytes32 questionHash;
    bytes32 answerHash;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer = vm.addr(4);

        vm.prank(owner);
        factHound = new FactHound(oracle, 100);

        // Setup question and answer
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        vm.deal(asker, 1 ether);
        vm.prank(asker);
        factHound.createQuestion{value: 1 ether}(questionHash);

        answerHash = keccak256(abi.encodePacked(answerer, "Yes"));
        vm.prank(answerer);
        factHound.createAnswer(questionHash, answerHash);

        vm.prank(asker);
        factHound.selectAnswer(questionHash, answerHash);
    }

    function testRedeemAnswer() public {
        uint initialBalance = answerer.balance;
        vm.prank(oracle);
        factHound.redeemAnswer(questionHash);

        assertEq(answerer.balance - initialBalance, 0.99 ether);
        (, , , FactHound.QuestionStatus status) = factHound.getQuestion(
            questionHash
        );
        assertEq(uint(status), uint(FactHound.QuestionStatus.RESOLVED));
    }

    function testRedeemAnswerRevertsIfNotOracle() public {
        vm.expectRevert(FactHound.NotOracle.selector);
        vm.prank(asker);
        factHound.redeemAnswer(questionHash);
    }
}

contract FactHoundTestRejectAnswer is Test {
    FactHound public factHound;
    address public owner;
    address public oracle;
    address public asker;
    address public answerer;
    bytes32 questionHash;
    bytes32 answerHash;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer = vm.addr(4);

        vm.prank(owner);
        factHound = new FactHound(oracle, 100);

        // Setup question and answer
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        vm.deal(asker, 1 ether);
        vm.prank(asker);
        factHound.createQuestion{value: 1 ether}(questionHash);

        answerHash = keccak256(abi.encodePacked(answerer, "Yes"));
        vm.prank(answerer);
        factHound.createAnswer(questionHash, answerHash);

        vm.prank(asker);
        factHound.selectAnswer(questionHash, answerHash);
    }

    function testRejectAnswer() public {
        vm.prank(oracle);
        factHound.rejectAnswer(questionHash);

        (, , , FactHound.QuestionStatus status) = factHound.getQuestion(
            questionHash
        );
        assertEq(uint(status), uint(FactHound.QuestionStatus.REJECTED));
    }

    function testRejectAnswerRevertsIfNotOracle() public {
        vm.expectRevert(FactHound.NotOracle.selector);
        vm.prank(asker);
        factHound.rejectAnswer(questionHash);
    }
}

contract FactHoundTestCancelQuestion is Test {
    FactHound public factHound;
    address public owner;
    address public oracle;
    address public asker;
    bytes32 questionHash;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);

        vm.prank(owner);
        factHound = new FactHound(oracle, 100);

        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        vm.deal(asker, 1 ether);
        vm.prank(asker);
        factHound.createQuestion{value: 1 ether}(questionHash);
    }

    function testCancelQuestion() public {
        uint initialBalance = asker.balance;
        vm.prank(owner);
        factHound.cancelQuestion(questionHash);

        assertEq(asker.balance - initialBalance, 0.99 ether);
        (, , , FactHound.QuestionStatus status) = factHound.getQuestion(
            questionHash
        );
        assertEq(uint(status), uint(FactHound.QuestionStatus.CANCELLED));
    }

    function testCancelQuestionRevertsIfNotOwner() public {
        vm.expectRevert(FactHound.NotOwner.selector);
        vm.prank(asker);
        factHound.cancelQuestion(questionHash);
    }
}

contract FactHoundTestAdministrative is Test {
    FactHound public factHound;
    address public owner;
    address public newOwner;
    address public oracle;

    function setUp() public {
        owner = vm.addr(1);
        newOwner = vm.addr(2);
        oracle = vm.addr(3);

        vm.prank(owner);
        factHound = new FactHound(oracle, 100);
        vm.deal(address(factHound), 1 ether);
    }

    function testSetOwner() public {
        vm.prank(owner);
        factHound.setOwner(newOwner);
        assertEq(factHound.owner(), newOwner);
    }

    function testSetOwnerRevertsIfNotOwner() public {
        vm.expectRevert(FactHound.NotOwner.selector);
        vm.prank(newOwner);
        factHound.setOwner(newOwner);
    }

    function testWithdraw() public {
        uint initialBalance = owner.balance;
        vm.prank(owner);
        factHound.withdraw();
        assertEq(owner.balance - initialBalance, 1 ether);
    }

    function testWithdrawRevertsIfNotOwner() public {
        vm.expectRevert(FactHound.NotOwner.selector);
        vm.prank(newOwner);
        factHound.withdraw();
    }
}

contract FactHoundTestMultipleQuestions is Test {
    FactHound public factHound;
    address public owner;
    address public oracle;
    address[] public askers;
    address[] public answerers;
    bytes32[] public questionHashes;
    bytes32[][] public answerHashes;
    uint public numQuestions;
    uint16 public asker_fee_per_10000;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        numQuestions = 1005;
        asker_fee_per_10000 = 100;

        // Setup multiple askers and answerers
        askers = new address[](numQuestions);
        answerers = new address[](numQuestions);
        for (uint i = 0; i < numQuestions; i++) {
            askers[i] = vm.addr(10 + i);
            answerers[i] = vm.addr(20 + i);
        }

        vm.prank(owner);
        factHound = new FactHound(oracle, asker_fee_per_10000);

        // Create multiple questions
        questionHashes = new bytes32[](numQuestions);
        answerHashes = new bytes32[][](numQuestions);
        for (uint i = 0; i < numQuestions; i++) {
            questionHashes[i] = keccak256(
                abi.encodePacked(
                    askers[i],
                    string(abi.encodePacked("Question", i))
                )
            );
            vm.deal(askers[i], 1 ether);
            vm.prank(askers[i]);
            factHound.createQuestion{value: 1 ether}(questionHashes[i]);
        }
    }

    function testMultipleQuestionsState() public view {
        for (uint i = 0; i < numQuestions; i++) {
            (
                address storedAsker,
                uint bounty,
                bytes32 selectedAnswer,
                FactHound.QuestionStatus status
            ) = factHound.getQuestion(questionHashes[i]);

            assertEq(storedAsker, askers[i]);
            assertEq(bounty, 0.99 ether);
            assertEq(selectedAnswer, bytes32(0));
            assertEq(uint(status), uint(FactHound.QuestionStatus.OPEN));
        }

        // Verify total bounty tracking
        assertEq(factHound.total_bounty(), 0.99 ether * numQuestions);
    }

    function testMultipleAnswersPerQuestion() public {
        uint answersPerQuestion = 3;

        // Create multiple answers for each question
        for (uint i = 0; i < numQuestions; i++) {
            for (uint j = 0; j < answersPerQuestion; j++) {
                bytes32 answerHash = keccak256(
                    abi.encodePacked(
                        answerers[i],
                        string(abi.encodePacked("Answer", i, "-", j))
                    )
                );
                vm.prank(answerers[i]);
                factHound.createAnswer(questionHashes[i], answerHash);
                answerHashes[i].push(answerHash);
            }
        }
    }

    function testParallelQuestionResolution() public {
        // Setup answers for all questions
        for (uint i = 0; i < numQuestions; i++) {
            bytes32 answerHash = keccak256(
                abi.encodePacked(
                    answerers[i],
                    string(abi.encodePacked("Answer", i))
                )
            );
            vm.prank(answerers[i]);
            factHound.createAnswer(questionHashes[i], answerHash);
            answerHashes[i].push(answerHash);
        }

        // Resolve questions in different states
        for (uint i = 0; i < numQuestions; i++) {
            vm.prank(askers[i]);
            factHound.selectAnswer(questionHashes[i], answerHashes[i][0]);

            if (i % 3 == 0) {
                // Redeem answer
                vm.prank(oracle);
                factHound.redeemAnswer(questionHashes[i]);
                (, , , FactHound.QuestionStatus status) = factHound.getQuestion(
                    questionHashes[i]
                );
                assertEq(uint(status), uint(FactHound.QuestionStatus.RESOLVED));
            } else if (i % 3 == 1) {
                // Reject answer
                vm.prank(oracle);
                factHound.rejectAnswer(questionHashes[i]);
                (, , , FactHound.QuestionStatus status) = factHound.getQuestion(
                    questionHashes[i]
                );
                assertEq(uint(status), uint(FactHound.QuestionStatus.REJECTED));
            } else {
                // Cancel question
                vm.prank(owner);
                factHound.cancelQuestion(questionHashes[i]);
                (, , , FactHound.QuestionStatus status) = factHound.getQuestion(
                    questionHashes[i]
                );
                assertEq(
                    uint(status),
                    uint(FactHound.QuestionStatus.CANCELLED)
                );
            }
        }
    }

    function testTotalBountyTracking() public {
        uint initialTotalBounty = factHound.total_bounty();

        // Resolve some questions
        for (uint i = 0; i < numQuestions; i++) {
            bytes32 answerHash = keccak256(
                abi.encodePacked(
                    answerers[i],
                    string(abi.encodePacked("Answer", i))
                )
            );
            vm.prank(answerers[i]);
            factHound.createAnswer(questionHashes[i], answerHash);

            vm.prank(askers[i]);
            factHound.selectAnswer(questionHashes[i], answerHash);

            if (i % 2 == 0) {
                vm.prank(oracle);
                factHound.redeemAnswer(questionHashes[i]);
            } else {
                vm.prank(oracle);
                factHound.rejectAnswer(questionHashes[i]);
            }
        }

        uint finalTotalBounty = factHound.total_bounty();
        assertEq(
            finalTotalBounty,
            initialTotalBounty - (0.99 ether * (1 + (numQuestions / 2)))
        );
    }
}
