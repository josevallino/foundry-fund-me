// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe test;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        //test = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deploy = new DeployFundMe();
        test = deploy.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMininumDollarIsFive() public view {
        assertEq(test.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(test.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = test.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // the next line should revert
        test.fund(); // send 0 value
    }

    function testFundUpdatesFundedDataStructures() public {
        vm.prank(USER); // the next TX will be sent by USER
        test.fund{value: SEND_VALUE}();

        uint256 amountFunded = test.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER); // the next TX will be sent by USER
        test.fund{value: SEND_VALUE}();

        address funder = test.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        test.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        test.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = test.getOwner().balance; // almacena el saldo del propietario del contrato antes de que se retiren los fondos.
        uint256 startingFundMeBalance = address(test).balance; // almacena el saldo del contrato FundMe antes de la retirada.

        // Act
        vm.prank(test.getOwner());
        test.withdraw(); // permite al propietario retirar los fondos del contrato.

        // Assert
        uint256 endingOwnerBalance = test.getOwner().balance; // almacena el saldo del propietario del contrato después de la retirada.
        uint256 endingFundMeBalance = address(test).balance; // almacena el saldo del contrato FundMe después de la retirada, que debería ser 0, ya que todos los fondos han sido retirados.
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFundersIndex = 1;
        for (uint160 i = startingFundersIndex; i < numberOfFunders; i++) {
            // vm.prank new address
            // vm.deal new address
            // address()
            hoax(address(i), SEND_VALUE); // hoax imula (o engaña) una llamada a una función como si fuera desde una dirección específica y con un balance determinado.
            test.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = test.getOwner().balance;
        uint256 startingFundMeBalance = address(test).balance;

        // Act
        vm.startPrank(test.getOwner());
        test.withdraw();
        vm.stopPrank();

        // Assert
        assert(address(test).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                test.getOwner().balance
        );
    }
}
