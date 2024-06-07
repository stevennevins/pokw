// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {PoKW} from "../src/PoKW.sol";
import {toWadUnsafe} from "../lib/solmate/src/utils/SignedWadMath.sol";

contract PoKWTest is Test {
    PoKW public pokw;

    function setUp() public {
        pokw = new PoKW(0);
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

    function testCalculateNewWorkWad() public {
        // Set a reasonable initial required work for testing
        uint256 initialRequiredWork = 1e18;
        pokw.updateRequiredWork(initialRequiredWork);

        // Simulate a scenario where observed time is greater than target time
        int256 observedTimeWad = toWadUnsafe(2 hours); // 2 hours in wad format
        int256 newWorkWad = pokw.calculateNewWorkWad(observedTimeWad);
        assertTrue(newWorkWad < toWadUnsafe(initialRequiredWork), "");

        // Simulate a scenario where observed time is less than target time
        observedTimeWad = toWadUnsafe(30 minutes); // 30 minutes in wad format
        newWorkWad = pokw.calculateNewWorkWad(observedTimeWad);
        assertTrue(newWorkWad > toWadUnsafe(initialRequiredWork), "");

        observedTimeWad = toWadUnsafe(1 hours); // 30 minutes in wad format
        newWorkWad = pokw.calculateNewWorkWad(observedTimeWad);
        assertApproxEqRel(
            newWorkWad,
            toWadUnsafe(initialRequiredWork),
            0.1e18,
            ""
        );
    }
}
