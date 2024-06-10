// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.26;

import {Auth} from "src/Auth.sol";
import {Test} from "forge-std/Test.sol";

contract Authed is Auth {
    function authedMethod() external auth {}
}

contract AuthTest is Test {
    Authed auth = new Authed();

    function testRely() external {
        assertTrue(auth.wards(address(this)), "msg.sender is not inited as ward");
        address user = makeAddr("user");
        assertFalse(auth.wards(user), "user is already a ward");
        vm.expectEmit();
        emit Auth.Rely(user);
        auth.rely(user);
        assertTrue(auth.wards(user), "user didnt become a ward");
    }

    function testDeny() external {
        address user = makeAddr("user");
        auth.rely(user);
        assertTrue(auth.wards(user), "user isnt a ward");
        vm.expectEmit();
        emit Auth.Deny(user);
        auth.deny(user);
        assertFalse(auth.wards(user), "user is still a ward");
    }

    function testAuthModifier() external {
        // self is a ward
        auth.authedMethod();

        address user1 = makeAddr("user1");
        assertFalse(auth.wards(user1), "user is a ward");
        vm.expectRevert(Auth.Auth__OnlyWards.selector);
        vm.prank(user1);
        auth.authedMethod();

        address user2 = makeAddr("user2");
        auth.rely(user2);
        // shouldn't revert
        auth.authedMethod();
    }
}
