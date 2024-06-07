// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {PoKW} from "../src/PoKW.sol";

contract PoKWTest is Test {
    PoKW public pokw;

    function setUp() public {
        pokw = new PoKW(type(uint256).max - 1);
    }

    function testWhitelistNode() public {
        address node = address(0x1);
        pokw.whitelistNode(node);
        bool isWhitelisted = pokw.nodes(node);
        assertTrue(isWhitelisted, "Node should be whitelisted");
    }

    function testFailWhitelistNodeTwice() public {
        address node = address(0x1);
        pokw.whitelistNode(node);
        pokw.whitelistNode(node); // This should fail
    }

    function testUpdateRequiredWork() public {
        pokw.updateRequiredWork(2000);
        uint256 requiredWork = pokw.requiredWork();
        assertEq(requiredWork, 2000, "Required work should be updated to 2000");
    }

    function testSubmitWorkValid() public {
        address node = address(0x1);
        pokw.whitelistNode(node);
        vm.warp(pokw.leadershipEndTime() + 1); // Warp to after the current leader's term is over

        uint256 validWork = 0;
        bool isValid = false;
        while (!isValid) {
            isValid = pokw.isValidWorkPreimage(node, validWork);
            if (!isValid) {
                validWork++;
            }
        }

        vm.prank(node);
        pokw.submitWork(validWork);
    }

    function test_RevertsWhen_NotWhitelisted() public {
        address node = address(0x2);
        vm.expectRevert();
        vm.prank(node);
        pokw.submitWork(500);
    }

    function testFailSubmitWorkInvalid() public {
        address node = address(0x1);
        pokw.whitelistNode(node);
        vm.prank(node);
        pokw.submitWork(2000); // Assuming 2000 is not a valid work (greater than requiredWork)
    }

    function testFailSubmitWorkDuringLeadership() public {
        address node = address(0x1);
        pokw.whitelistNode(node);
        vm.prank(node);
        pokw.submitWork(500); // Valid work submission
        vm.prank(node);
        pokw.submitWork(500); // This should fail as the leadership term is not over
    }

    function testExpApproximation() public {
        // Test the exp function with a small positive value
        int256 testValue1 = 1;
        uint256 result1 = pokw.exp(testValue1);
        uint256 expected1 = 2; // Approximate value of e^1 * 10^6 for precision
        assertApproxEqRel(
            result1,
            expected1,
            0.1e18,
            "Exponential function approximation for e^1 is incorrect"
        );

        // Test the exp function with zero
        int256 testValue3 = 0;
        uint256 result3 = pokw.exp(testValue3);
        uint256 expected3 = 1; // e^0 is 1, scaled by 10^6 for precision
        assertApproxEqRel(
            result3,
            expected3,
            0.1e18,
            "Exponential function approximation for e^0 is incorrect"
        );
    }
}
