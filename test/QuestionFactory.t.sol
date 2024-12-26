// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {QuestionFactory} from "../src/QuestionFactory.sol";
import {Question} from "../src/Question.sol";

contract QuestionFactoryTestCreateQuestion is Test {
    QuestionFactory public questionFactory;
    address public owner;
    address public oracle;
    uint8 public asker_fee_per_10000;
    uint bounty;
    address asker;
    address answerer;
    bytes32 questionHash;
    bytes32 answerHash;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        asker = vm.addr(3);
        answerer = vm.addr(4);
        asker_fee_per_10000 = 100;
        vm.prank(owner);
        questionFactory = new QuestionFactory(oracle, asker_fee_per_10000);
    }

    function testCreateQuestion() public {
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        assertEq(questionFactory.getQuestion(questionHash), address(0));
        vm.deal(asker, 1 ether);
        vm.prank(asker);
        questionFactory.createQuestion{value: 1 ether}(questionHash);
        // make sure the question was created properly
        assertNotEq(questionFactory.getQuestion(questionHash), address(0));
        assertEq(questionFactory.getQuestion(questionHash).balance, .99 ether);
        // test some basic Question functions
        Question question = Question(questionFactory.getQuestion(questionHash));
        answerHash = keccak256(
            abi.encodePacked(answerer, "No, this is not a test.")
        );
        assertEq(question.answerInfoMap(answerHash), address(0));
        vm.prank(answerer);
        question.createAnswer(answerHash);
        assertEq(question.answerInfoMap(answerHash), answerer);
    }

    function testCreateQuestionRevertsIfAlreadyExists() public {
        questionHash = keccak256(abi.encodePacked(asker, "Is this a test?"));
        assertEq(questionFactory.getQuestion(questionHash), address(0));
        vm.deal(asker, 1 ether);
        vm.prank(asker);
        questionFactory.createQuestion{value: 1 ether}(questionHash);
        // reverts if we try to ask the same question again
        vm.deal(asker, 1 ether);
        vm.expectRevert();
        vm.prank(asker);
        questionFactory.createQuestion{value: 1 ether}(questionHash);
    }
}

contract QuestionFactoryTestSetOwner is Test {
    QuestionFactory public questionFactory;
    address public owner;
    address public newOwner;
    address public oracle;
    uint8 public asker_fee_per_10000;
    uint bounty;
    address asker;
    address answerer;
    bytes32 questionHash;
    bytes32 answerHash;

    function setUp() public {
        owner = vm.addr(1);
        oracle = vm.addr(2);
        newOwner = vm.addr(5);
        asker_fee_per_10000 = 100;
        vm.prank(owner);
        questionFactory = new QuestionFactory(oracle, asker_fee_per_10000);
    }

    function testSetOwner() public {
        vm.prank(owner);
        questionFactory.setOwner(newOwner);
        assertEq(questionFactory.owner(), newOwner);
    }

    function testSetOwnerRevertsIfNotOwner() public {
        assertNotEq(questionFactory.owner(), newOwner);
        vm.expectRevert();
        vm.prank(newOwner);
        questionFactory.setOwner(newOwner);
    }
}
