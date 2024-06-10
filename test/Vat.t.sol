// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vat, Auth} from "src/Vat.sol";

contract VatTest is Test {
    Vat vat = new Vat();
    address mockJoin = makeAddr("mockJoin");
    address gem1 = makeAddr("gem1");
    address notRelyed = makeAddr("notRelyed");

    function setUp() external {
        assertTrue(vat.wards(address(this)), "self is not a ward");
        vat.rely(mockJoin);
    }

    function testHope() external {
        address user = makeAddr("user");
        assertFalse(vat.can(address(this), user), "user is already hoped");
        vm.expectEmit();
        emit Vat.Hope(address(this), user);
        vat.hope(user);
        assertTrue(vat.can(address(this), user), "user is still not hoped");
    }

    function testNope() external {
        address user = makeAddr("user");
        vat.hope(user);
        assertTrue(vat.can(address(this), user), "user is not hoped");
        vm.expectEmit();
        emit Vat.Nope(address(this), user);
        vat.nope(user);
        assertFalse(vat.can(address(this), user), "user is still hoped");
    }

    function testSlip(uint256 amt, uint256 plus, uint256 minus) external {
        address who = makeAddr("who");

        uint256 max = uint256(type(int256).max);
        amt = bound(amt, 0, uint256(type(int256).max));

        uint256 maxPlus = max - amt;
        plus = bound(plus, 0, maxPlus);

        uint256 maxMinus = amt + plus;
        minus = bound(minus, 0, maxMinus);

        vat.slip(gem1, who, int256(amt));
        assertEq(vat.gem(gem1, who), amt, "initial vat.slip set not as expected");

        vat.slip(gem1, who, int256(plus));
        assertEq(vat.gem(gem1, who), amt + plus, "vat.slip addition not as expected");

        vat.slip(gem1, who, -int256(minus));
        assertEq(vat.gem(gem1, who), amt + plus - minus, "vat.slip subtraction not as expected");
    }

    function testSlip() external {
        address user = makeAddr("user");
        address user2 = makeAddr("user");

        // only wards can slip
        vm.expectRevert(Auth.Auth__OnlyWards.selector);
        vm.prank(notRelyed);
        vat.slip(gem1, user, int256(100));

        // mockJoin is relyed, so can slip
        vm.expectEmit();
        emit Vat.Slip(gem1, user, type(int256).max);
        vm.prank(mockJoin);
        vat.slip(gem1, user, type(int256).max);

        // max gem value stored is type(int).max, should revert for more than that
        // overflow is protected by default solidity checked method
        vm.expectRevert(_solidityOverUnderflowError());
        vm.prank(mockJoin);
        vat.slip(gem1, user, int256(1));

        // negative values not allowed
        vm.prank(mockJoin);
        vat.slip(gem1, user, -type(int256).max);
        vm.expectRevert(Vat.Vat__OverUnderFlow.selector);
        vm.prank(mockJoin);
        vat.slip(gem1, user, -int256(1));

        // test slip function
        assertEq(vat.gem(gem1, user2), 0, "gem balance is not 0");
        vat.slip(gem1, user2, 100);
        assertEq(vat.gem(gem1, user2), 100, "gem balance did not increase as expected");
        vat.slip(gem1, user2, 10);
        assertEq(vat.gem(gem1, user2), 110, "gem balance did not increase as expected");
        vat.slip(gem1, user2, -10);
        assertEq(vat.gem(gem1, user2), 100, "gem balance did not decrease as expected");
    }

    function testFluxEvent() external {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        // fund some gem
        vat.slip(gem1, user1, int256(10 ether));

        // flux and test event
        vm.expectEmit();
        emit Vat.Flux(gem1, user1, user2, 100);
        vm.prank(user1);
        vat.flux(gem1, user1, user2, 100);
    }

    function testFluxHopeNope() external {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address hoped = makeAddr("hoped");
        address noped = makeAddr("noped");

        // fund some gem
        vat.slip(gem1, user1, int256(10 ether));

        vm.prank(user1);
        vat.hope(hoped);

        vm.prank(user1);
        vat.nope(noped);

        // noped user cannot flux on behalf of user
        vm.expectRevert(Vat.Vat__NotAuthed.selector);
        vm.prank(noped);
        vat.flux(gem1, user1, user2, 100);

        // hoped user can flux on behalf of user
        vm.prank(hoped);
        vat.flux(gem1, user1, user2, 100);
    }

    function testFluxOverflow() external {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        // fund some gems
        vat.slip(gem1, user1, 10 ether);
        vat.slip(gem1, user2, type(int256).max - 100);

        // max for any user cannot go over type(int).max
        vm.prank(user1);
        vm.expectRevert(Vat.Vat__OverUnderFlow.selector);
        vat.flux(gem1, user1, user2, 101);

        // cannot transfer more than available balance
        uint256 currUser1Bal = vat.gem(gem1, user1);
        vm.prank(user1);
        vm.expectRevert(_solidityOverUnderflowError());
        vat.flux(gem1, user1, user3, currUser1Bal + 1);
    }

    function testFlux(uint256 start1, uint256 start2, uint256 amt) external {
        uint256 max = uint256(type(int256).max);
        amt = bound(amt, 0, start1);
        start1 = bound(start1, 0, max);
        start2 = bound(start2, 0, max);
        uint256 diff = max - start2;
        amt = amt < diff ? amt : diff;

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        vat.slip(gem1, user1, int256(start1));
        vat.slip(gem1, user2, int256(start2));

        vm.prank(user1);
        vat.flux(gem1, user1, user2, amt);

        assertEq(vat.gem(gem1, user1), start1 - amt, "src balance is incorrect");
        assertEq(vat.gem(gem1, user2), start2 + amt, "dst balance is incorrect");
    }

    function _solidityOverUnderflowError() internal pure returns (bytes memory) {
        return abi.encodeWithSignature("Panic(uint256)", 0x11);
    }
}
