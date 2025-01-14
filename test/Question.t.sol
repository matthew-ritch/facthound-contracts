// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {Question} from "../src/Question.sol";

contract QuestionTestCreateAnswer is Test {
    Question public question;
    address owner;
    address oracle;
    address asker;
    address answerer1;
    address answerer2;
    bytes32 questionHash;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);
        // question is asked
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        question = new Question(owner, oracle, asker, questionHash);
    }

    function testCreateAnswer() public {
        bytes32 answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        assertEq(question.answerInfoMap(answerHash1), address(0));
        vm.prank(answerer1);
        question.createAnswer(answerHash1);
        bytes32 answerHash2 = keccak256(
            abi.encodePacked(answerer2, "Yes, this is a test.")
        );
        assertEq(question.answerInfoMap(answerHash2), address(0));
        vm.prank(answerer2);
        question.createAnswer(answerHash2);
        //
        assertEq(question.answerInfoMap(answerHash1), answerer1);
        assertEq(question.answerInfoMap(answerHash2), answerer2);
    }

    function testCreateAnswerRevertsIfAlreadyExists() public {
        vm.prank(answerer1);
        bytes32 answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        question.createAnswer(answerHash1);
        // ensure revert
        vm.expectRevert();
        question.createAnswer(answerHash1);
    }
}

contract QuestionTestSelectAnswer is Test {
    Question public question;
    address owner;
    address oracle;
    address asker;
    address answerer1;
    address answerer2;
    bytes32 questionHash;
    bytes32 answerHash1;
    bytes32 answerHash2;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);
        // question is asked
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        question = new Question(owner, oracle, asker, questionHash);
        // question is answered by two different answerers
        answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        assertEq(question.answerInfoMap(answerHash1), address(0));
        vm.prank(answerer1);
        question.createAnswer(answerHash1);
        answerHash2 = keccak256(
            abi.encodePacked(answerer2, "Yes, this is a test.")
        );
        assertEq(question.answerInfoMap(answerHash2), address(0));
        vm.prank(answerer2);
        question.createAnswer(answerHash2);
    }

    function testCreateAnswerRevertsIfAlreadyExists() public {
        vm.expectRevert();
        question.createAnswer(answerHash1);
    }

    function testSelectAnswerAsker() public {
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        //
        assertEq(question.selectedAnswer(), answerHash2);
        assertNotEq(question.selectedAnswer(), answerHash1);
    }

    function testChangeSelectAnswerAsker() public {
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        vm.prank(asker);
        question.selectAnswer(answerHash1);
        //
        assertEq(question.selectedAnswer(), answerHash1);
        assertNotEq(question.selectedAnswer(), answerHash2);
    }

    function testSelectAnswerOracle() public {
        vm.prank(oracle);
        question.selectAnswer(answerHash2);
        //
        assertEq(question.selectedAnswer(), answerHash2);
        assertNotEq(question.selectedAnswer(), answerHash1);
    }

    function testChangeSelectAnswerOracle() public {
        vm.prank(oracle);
        question.selectAnswer(answerHash2);
        vm.prank(oracle);
        question.selectAnswer(answerHash1);
        //
        assertEq(question.selectedAnswer(), answerHash1);
        assertNotEq(question.selectedAnswer(), answerHash2);
    }

    function testSelectAnswerRevertsIfNotAskerOrOracle() public {
        vm.expectRevert();
        vm.prank(answerer1);
        question.selectAnswer(answerHash2);
        assertNotEq(question.selectedAnswer(), answerHash2);
    }

    function testSelectAnswerRevertsForAskerAfterRejection() public {
        vm.prank(asker);
        question.selectAnswer(answerHash1);
        vm.prank(oracle);
        question.rejectAnswer();
        vm.prank(oracle);
        question.selectAnswer(answerHash2);
        // ensure revert
        vm.expectRevert();
        vm.prank(asker);
        question.selectAnswer(answerHash1);
        assertNotEq(question.selectedAnswer(), answerHash1);
        assertEq(question.selectedAnswer(), answerHash2);
    }

    function testSelectAnswerRevertsIfAlreadyResolved() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle certifies
        vm.prank(oracle);
        question.certifyAnswer();
        // oracle pays out
        vm.prank(oracle);
        question.redeemBounty();
        // ensure revert
        vm.expectRevert();
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        vm.expectRevert();
        vm.prank(oracle);
        question.selectAnswer(answerHash2);
    }
}

contract QuestionTestCertifyAnswer is Test {
    Question public question;
    address owner;
    address oracle;
    address asker;
    address answerer1;
    address answerer2;
    bytes32 questionHash;
    bytes32 answerHash1;
    bytes32 answerHash2;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);
        // question is asked
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        question = new Question(owner, oracle, asker, questionHash);
        // question is answered by two different answerers
        answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        vm.prank(answerer1);
        question.createAnswer(answerHash1);
        answerHash2 = keccak256(
            abi.encodePacked(answerer2, "Yes, this is a test.")
        );
        vm.prank(answerer2);
        question.createAnswer(answerHash2);
    }

    function testCertifyAnswer() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        //
        assertFalse(question.isCertified());
        //
        vm.prank(oracle);
        question.certifyAnswer();
        //
        assertTrue(question.isCertified());
    }

    function testCertifyAnswerRevertsIfNotOracle() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // ensure revert
        vm.expectRevert();
        vm.prank(asker);
        question.certifyAnswer();
        //
        vm.expectRevert();
        vm.prank(answerer1);
        question.certifyAnswer();
        //
        vm.expectRevert();
        vm.prank(answerer2);
        question.certifyAnswer();
        //
        vm.expectRevert();
        vm.prank(owner);
        question.certifyAnswer();
    }

    function testCertifyAnswerRevertsIfNoAnswerSelected() public {
        vm.expectRevert();
        vm.prank(oracle);
        question.certifyAnswer();
    }

    function testCertifyAnswerRevertsIfAlreadyResolved() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle certifies
        vm.prank(oracle);
        question.certifyAnswer();
        // oracle pays out
        vm.prank(oracle);
        question.redeemBounty();
        //
        vm.expectRevert();
        vm.prank(oracle);
        question.certifyAnswer();
    }
}

contract QuestionTestRejectAnswer is Test {
    Question public question;
    address owner;
    address oracle;
    address asker;
    address answerer1;
    address answerer2;
    bytes32 questionHash;
    bytes32 answerHash1;
    bytes32 answerHash2;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);
        // question is asked
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        question = new Question(owner, oracle, asker, questionHash);
        // question is answered by two different answerers
        answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        vm.prank(answerer1);
        question.createAnswer(answerHash1);
        answerHash2 = keccak256(
            abi.encodePacked(answerer2, "Yes, this is a test.")
        );
        vm.prank(answerer2);
        question.createAnswer(answerHash2);
    }

    function testRejectAnswer() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        //
        assertFalse(question.isCertified());
        //
        assertFalse(question.askerSelectionRejected());
        vm.prank(oracle);
        question.rejectAnswer();
        //
        assertFalse(question.isCertified());
        assertTrue(question.askerSelectionRejected());
    }

    function testRejectAnswerRevertsIfNotOracle() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // ensure reverts
        vm.expectRevert();
        vm.prank(asker);
        question.rejectAnswer();
        //
        vm.expectRevert();
        vm.prank(answerer1);
        question.rejectAnswer();
        //
        vm.expectRevert();
        vm.prank(answerer2);
        question.rejectAnswer();
        //
        vm.expectRevert();
        vm.prank(owner);
        question.rejectAnswer();
    }

    function testRejectAnswerRevertsIfNoAnswerSelected() public {
        vm.expectRevert();
        vm.prank(oracle);
        question.rejectAnswer();
    }

    function testRejectAnswerRevertsIfAlreadyResolved() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle certifies
        vm.prank(oracle);
        question.certifyAnswer();
        // oracle pays out
        vm.prank(oracle);
        question.redeemBounty();
        // ensure revert
        vm.expectRevert();
        vm.prank(oracle);
        question.rejectAnswer();
    }

    function testSelectAnswerRevertsForAskerAfterRejection() public {
        vm.prank(asker);
        question.selectAnswer(answerHash1);
        vm.prank(oracle);
        question.rejectAnswer();
        vm.prank(oracle);
        question.selectAnswer(answerHash2);
        // ensure revert
        vm.expectRevert();
        vm.prank(asker);
        question.selectAnswer(answerHash1);
        assertNotEq(question.selectedAnswer(), answerHash1);
        assertEq(question.selectedAnswer(), answerHash2);
    }
}

contract QuestionTestRedeemBounty is Test {
    Question public question;
    address owner;
    address oracle;
    address asker;
    address answerer1;
    address answerer2;
    bytes32 questionHash;
    bytes32 answerHash1;
    bytes32 answerHash2;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);
        // question is asked
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        question = new Question(owner, oracle, asker, questionHash);
        // send the question some eth
        vm.deal(address(question), 1);
        // question is answered by two different answerers
        answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        vm.prank(answerer1);
        question.createAnswer(answerHash1);
        answerHash2 = keccak256(
            abi.encodePacked(answerer2, "Yes, this is a test.")
        );
        vm.prank(answerer2);
        question.createAnswer(answerHash2);
    }

    function testRedeemBountyRevertsIfNotOracle() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle certifies
        vm.prank(oracle);
        question.certifyAnswer();
        // ensure reverts
        vm.expectRevert();
        vm.prank(asker);
        question.redeemBounty();
        //
        vm.expectRevert();
        vm.prank(answerer1);
        question.redeemBounty();
        //
        vm.expectRevert();
        vm.prank(answerer2);
        question.redeemBounty();
        //
        vm.expectRevert();
        vm.prank(owner);
        question.redeemBounty();
    }

    function testRedeemBountyRevertsIfAnswerNotSelected() public {
        assertEq(question.selectedAnswer(), 0);
        vm.expectRevert();
        vm.prank(oracle);
        question.redeemBounty();
    }

    function testRedeemBountyRevertsIfAnswerNotCertified() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // ensure revert
        assert(!question.isCertified());
        vm.expectRevert();
        vm.prank(oracle);
        question.redeemBounty();
    }

    function testRedeemBountyRevertsIfQuestionResolved() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle certifies
        vm.prank(oracle);
        question.certifyAnswer();
        // oracle pays out
        vm.prank(oracle);
        question.redeemBounty();
        // ensure revert
        assert(question.isResolved());
        vm.expectRevert();
        vm.prank(oracle);
        question.redeemBounty();
    }

    function testRedeemBountyReturnsTheBountyToAsker() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle certifies
        vm.prank(oracle);
        question.certifyAnswer();
        // set answerer2's balance to 0
        vm.deal(answerer2, 0);
        // oracle pays out
        vm.prank(oracle);
        question.redeemBounty();
        // make sure they were paid out
        assertEq(answerer2.balance, 1);
    }
}

contract QuestionTestCertifyAndRedeemAnswer is Test {
    Question public question;
    address owner;
    address oracle;
    address asker;
    address answerer1;
    address answerer2;
    bytes32 questionHash;
    bytes32 answerHash1;
    bytes32 answerHash2;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);
        // question is asked
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        question = new Question(owner, oracle, asker, questionHash);
        // send the question some eth
        vm.deal(address(question), 1);
        // question is answered by two different answerers
        answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        vm.prank(answerer1);
        question.createAnswer(answerHash1);
        answerHash2 = keccak256(
            abi.encodePacked(answerer2, "Yes, this is a test.")
        );
        vm.prank(answerer2);
        question.createAnswer(answerHash2);
    }

    function testCertifyAndRedeemAnswerRevertsIfNotOracle() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // ensure reverts
        vm.expectRevert();
        vm.prank(asker);
        question.certifyAndRedeemAnswer();
        //
        vm.expectRevert();
        vm.prank(answerer1);
        question.certifyAndRedeemAnswer();
        //
        vm.expectRevert();
        vm.prank(answerer2);
        question.certifyAndRedeemAnswer();
        //
        vm.expectRevert();
        vm.prank(owner);
        question.certifyAndRedeemAnswer();
    }

    function testCertifyAndRedeemAnswerRevertsIfAnswerNotSelected() public {
        assertEq(question.selectedAnswer(), 0);
        vm.expectRevert();
        vm.prank(oracle);
        question.certifyAndRedeemAnswer();
    }

    function testCertifyAndRedeemAnswerRevertsIfQuestionResolved() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle certifies and pays out
        vm.prank(oracle);
        question.certifyAndRedeemAnswer();
        // ensure revert
        assert(question.isResolved());
        vm.expectRevert();
        vm.prank(oracle);
        question.certifyAndRedeemAnswer();
    }

    function testCertifyAndRedeemAnswerReturnsTheBountyToAsker() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // set answerer2's balance to 0
        vm.deal(answerer2, 0);
        // oracle certifies and pays out
        vm.prank(oracle);
        question.certifyAndRedeemAnswer();
        // make sure they were paid out
        assertEq(answerer2.balance, 1);
    }
}

contract QuestionTestCancel is Test {
    Question public question;
    address owner;
    address oracle;
    address asker;
    address answerer1;
    address answerer2;
    bytes32 questionHash;
    bytes32 answerHash1;
    bytes32 answerHash2;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);
        // question is asked
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        question = new Question(owner, oracle, asker, questionHash);
        // send the question some eth:
        vm.deal(address(question), 1);
        // question is answered by two different answerers
        answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        vm.prank(answerer1);
        question.createAnswer(answerHash1);
        answerHash2 = keccak256(
            abi.encodePacked(answerer2, "Yes, this is a test.")
        );
        vm.prank(answerer2);
        question.createAnswer(answerHash2);
    }

    function testCancel() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle rejects
        vm.prank(oracle);
        question.rejectAnswer();
        // set asker's balance to 0
        vm.deal(asker, 0);
        // cancel question
        vm.prank(owner);
        question.cancel();
        //
        assert(question.isCancelled());
    }

    function testCancelRevertsIfAlreadyResolved() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle certifies
        vm.prank(oracle);
        question.certifyAnswer();
        // oracle pays out
        vm.prank(oracle);
        question.redeemBounty();
        // ensure revert
        assert(question.isResolved());
        vm.expectRevert();
        vm.prank(owner);
        question.cancel();
    }

    function testCancelTransfersBountyBackToAsker() public {
        // set balances to 0
        vm.deal(answerer1, 0);
        vm.deal(answerer2, 0);
        vm.deal(asker, 0);
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle rejects
        vm.prank(oracle);
        question.rejectAnswer();
        // cancel question
        vm.prank(owner);
        question.cancel();
        //
        assert(question.isCancelled());
        assertEq(asker.balance, 1);
        assertEq(answerer1.balance, 0);
        assertEq(answerer2.balance, 0);
    }

    function testCancelRevertsIfNotOwner() public {
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // ensure reverts
        vm.expectRevert();
        vm.prank(asker);
        question.cancel();
        //
        vm.expectRevert();
        vm.prank(answerer1);
        question.cancel();
        //
        vm.expectRevert();
        vm.prank(answerer2);
        question.cancel();
        //
        vm.expectRevert();
        vm.prank(oracle);
        question.cancel();
    }
}

contract QuestionTestNothingAfterCancel is Test {
    Question public question;
    address owner;
    address oracle;
    address asker;
    address answerer1;
    address answerer2;
    bytes32 questionHash;
    bytes32 answerHash1;
    bytes32 answerHash2;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer1 = vm.addr(4);
        answerer2 = vm.addr(5);
        // question is asked
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        question = new Question(owner, oracle, asker, questionHash);
        // send the question some eth
        vm.deal(address(question), 1);
        // question is answered by two different answerers
        answerHash1 = keccak256(
            abi.encodePacked(answerer1, "No, this is not a test.")
        );
        vm.prank(answerer1);
        question.createAnswer(answerHash1);
        answerHash2 = keccak256(
            abi.encodePacked(answerer2, "Yes, this is a test.")
        );
        vm.prank(answerer2);
        question.createAnswer(answerHash2);
        // asker selects an answer
        vm.prank(asker);
        question.selectAnswer(answerHash2);
        // oracle rejects
        vm.prank(oracle);
        question.rejectAnswer();
        // set asker's balance to 0
        vm.deal(asker, 0);
        // cancel question
        vm.prank(owner);
        question.cancel();
    }

    function testCreateAnswerReverts() public {
        bytes32 answerHash3 = keccak256(
            abi.encodePacked(answerer1, "Actually, maybe this is a test.")
        );
        vm.expectRevert();
        vm.prank(answerer1);
        question.createAnswer(answerHash3);
    }

    function testSelectAnswerReverts() public {
        vm.expectRevert();
        vm.prank(asker);
        question.selectAnswer(answerHash2);
    }

    function testCertifyAnswerReverts() public {
        vm.expectRevert();
        vm.prank(oracle);
        question.certifyAnswer();
    }

    function testRejectAnswerReverts() public {
        vm.expectRevert();
        vm.prank(oracle);
        question.rejectAnswer();
    }

    function testRedeemBountyReverts() public {
        vm.expectRevert();
        vm.prank(owner);
        question.redeemBounty();
    }

    function testCancelReverts() public {
        vm.expectRevert();
        vm.prank(owner);
        question.cancel();
    }
}
