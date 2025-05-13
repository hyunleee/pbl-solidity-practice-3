// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { ChizToken } from "../src/ChizToken.sol";

contract ChizTokenTest is Test {
    ChizToken chiz;
    address admin;
    address user;

    uint256 initialRate   = 100 * 10**18;
    uint256 initialSupply = 1000 * 10**18;

    // 이벤트 시그니쳐 재선언 (expectEmit 용)
    event TokensPurchased(address indexed buyer, uint256 amountOfETH, uint256 amountOfTokens);
    event TokensWithdrawn(address indexed target, uint256 amountOfETH);

    function setUp() public {
        admin = address(this);
        user  = address(0xABCD);
        vm.deal(user, 10 ether);

        chiz = new ChizToken("Chiz", "CHIZ", initialRate, initialSupply);
    }

    function test_AdminIsSet() public {
        assertEq(chiz.admin(), admin);
    }

    function test_InitialParameters() public {
        assertEq(chiz.name(), "Chiz");
        assertEq(chiz.symbol(), "CHIZ");
        assertEq(chiz.exchangeRate(), initialRate);
        assertEq(chiz.totalSupply(), initialSupply);
        assertEq(chiz.balanceOf(admin), initialSupply);
    }

    function test_MintByAdmin() public {
        uint256 amount = 50 * 10**18;
        chiz.mint(user, amount);
        assertEq(chiz.balanceOf(user), amount);
    }

    function test_MintRevertsForNonAdmin() public {
        uint256 amount = 10 * 10**18;
        vm.prank(user);
        vm.expectRevert("Only admin can mint tokens");
        chiz.mint(user, amount);
    }

    function test_BuyTokensRevertsWithoutETH() public {
        vm.prank(user);
        vm.expectRevert("You must send ETH to buy tokens");
        chiz.buyTokens();
    }

    function test_BuyTokensMintsCorrectAmountAndEmits() public {
        uint256 ethAmount     = 1 ether;
        uint256 expectedTokens = (ethAmount * initialRate) / (10**chiz.decimals());

        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit TokensPurchased(user, ethAmount, expectedTokens);
        chiz.buyTokens{ value: ethAmount }();

        assertEq(chiz.balanceOf(user), expectedTokens);
        assertEq(chiz.getContractBalance(), ethAmount);
    }

    function test_SellTokensRevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert("You must sell at least some tokens");
        chiz.sellTokens(0);
    }

    function test_SellTokensRevertsOnInsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert("Insufficient balance");
        chiz.sellTokens(1);
    }

    function test_SellTokensTransfersETHAndEmits() public {
        uint256 ethAmount = 2 ether;
        vm.prank(user); 
        chiz.buyTokens{ value: ethAmount }();

        uint256 tokenBal  = chiz.balanceOf(user);
        uint256 expectedETH = (tokenBal * (10**chiz.decimals())) / initialRate;

        vm.startPrank(user);
        uint256 balanceBefore = user.balance;

        vm.expectEmit(true, true, false, true);
        emit TokensWithdrawn(user, expectedETH);
        chiz.sellTokens(tokenBal);

        uint256 balanceAfter = user.balance;
        assertEq(balanceAfter - balanceBefore, expectedETH);
        assertEq(chiz.getContractBalance(), 0);
        vm.stopPrank();
    }

    function test_SetExchangeRateByAdmin() public {
        uint256 newRate = 200 * 10**18;
        chiz.setExchangeRate(newRate);
        assertEq(chiz.exchangeRate(), newRate);
    }

    function test_SetExchangeRateRevertsForNonAdmin() public {
        vm.prank(user);
        vm.expectRevert("Only admin can mint tokens");
        chiz.setExchangeRate(1);
    }

    // fallback 수용
    receive() external payable {}
}
