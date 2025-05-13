// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { Bottle } from "../src/Bottle.sol";
import { BottleInterface } from "../src/interface/BottleInterface.sol";
import { ChizToken } from "../src/ChizToken.sol";

contract BottleTest is Test {
    Bottle public bottle;
    ChizToken public token;
    address public admin;
    address public alice;
    address public bob;

    uint256 initialRate   = 100 * 10**18;
    uint256 initialSupply = 1000 * 10**18;

    // 이벤트 시그니처 재선언 (expectEmit 용)
    event Launch(uint256 indexed bottleId, BottleInterface.BottleData launchedBottle);
    event Cancel(uint256 indexed bottleId);
    event Pledge(uint256 indexed bottleId, address indexed caller, uint256 amount, uint256 totalAmount);
    event Unpledge(uint256 indexed bottleId, address indexed caller, uint256 amount, uint256 totalAmount);
    event Claim(uint256 indexed bottleId, bool claimed, uint256 amount);
    event Refund(uint256 indexed bottleId, address indexed caller, uint256 amount);

    function setUp() public {
        admin = address(this);
        alice = address(0x1);
        bob   = address(0x2);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        token  = new ChizToken("Chiz", "CHIZ", initialRate, initialSupply);
        bottle = new Bottle(address(token));
        token.approve(address(bottle), type(uint256).max);
    }

    function test_LaunchCampaign() public {
        uint32 start = uint32(block.timestamp + 1);
        uint32 end   = start + 1 days;

        // Expect Launch event: only bottleId indexed, ignore struct
        vm.expectEmit(true, false, false, false, address(bottle));
        emit Launch(1, bottle.getBottle(1));

        bottle.launch(alice, "Title", "Desc", 100, start, end);

        BottleInterface.BottleData memory b = bottle.getBottle(1);
        assertEq(b.creator, admin);
        assertEq(b.target, alice);
        assertEq(b.title, "Title");
        assertEq(b.goal, 100);
    }

    function test_CancelBeforeStart() public {
        uint32 start = uint32(block.timestamp + 100);
        uint32 end   = start + 1 days;

        bottle.launch(alice, "T", "D", 100, start, end);
        bottle.cancel(1);

        BottleInterface.BottleData memory b = bottle.getBottle(1);
        // Deleted bottle resets to default struct: goal == 0
        assertEq(b.goal, 0);
    }

    function test_CancelRevertsAfterStart() public {
        uint32 start = uint32(block.timestamp + 1);
        uint32 end   = start + 1 days;

        bottle.launch(alice, "T", "D", 100, start, end);
        vm.warp(start + 1);
        vm.expectRevert("started");
        bottle.cancel(1);
    }

    function test_PledgeAndUnpledgeFlow() public {
        uint32 start = uint32(block.timestamp + 1);
        uint32 end   = start + 1 days;

        bottle.launch(alice, "T", "D", 100, start, end);
        vm.warp(start + 1);

        token.mint(bob, 200);
        vm.startPrank(bob);
        token.approve(address(bottle), 200);

        // Expect Pledge event
        vm.expectEmit(true, true, false, false, address(bottle));
        emit Pledge(1, bob, 50, 50);
        bottle.pledge(1, 50);
        assertEq(bottle.getBottleTotalAmount(1), 50);

        // Expect Unpledge event
        vm.expectEmit(true, true, false, false, address(bottle));
        emit Unpledge(1, bob, 20, 30);
        bottle.unpledge(1, 20);
        assertEq(bottle.getBottleTotalAmount(1), 30);

        vm.stopPrank();
    }

    function test_ClaimAndRefund() public {
        uint32 start = uint32(block.timestamp + 1);
        uint32 end   = start + 1 days;

        // 캠페인 생성 및 기부
        bottle.launch(alice, "T", "D", 100, start, end);
        vm.warp(start + 1);
        token.mint(bob, 200);

        vm.startPrank(bob);
        token.approve(address(bottle), 200);
        bottle.pledge(1, 100);
        vm.stopPrank();

        // ---------- Claim ----------
        bottle.claim(1);
        assertTrue(bottle.getBottle(1).claimed);

        // ---------- Refund(불가) ----------
        vm.warp(end + 1);
        vm.startPrank(bob);
        vm.expectRevert();            // 잔고 부족으로 revert 기대
        bottle.refund(1);
        vm.stopPrank();
    }

    function test_RefundAfterFailure() public {
        uint32 start = uint32(block.timestamp + 1);
        uint32 end   = start + 1 days;

        bottle.launch(alice, "T", "D", 100, start, end);
        vm.warp(start + 1);
        token.mint(bob, 200);
        vm.startPrank(bob);
        token.approve(address(bottle), 200);
        bottle.pledge(1, 50);
        vm.stopPrank();

        // Warp past end
        vm.warp(end + 1);

        // Refund event
        vm.startPrank(bob);
        uint256 balBefore = token.balanceOf(bob);
        vm.expectEmit(true, true, false, false, address(bottle));
        emit Refund(1, bob, 50);
        bottle.refund(1);
        uint256 balAfter = token.balanceOf(bob);
        assertEq(balAfter - balBefore, 50);
        vm.stopPrank();
    }
}
