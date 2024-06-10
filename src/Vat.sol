// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.26;

import {Auth} from "./Auth.sol";

/// Modified from https://github.com/makerdao/dss/blob/fa4f6630afb0624d04a003e920b0d71a00331d98/src/vat.sol
contract Vat is Auth {
    error Vat__NotAuthed();
    error Vat__OverUnderFlow();

    event Hope(address indexed usr, address indexed who);
    event Nope(address indexed usr, address indexed who);
    event Slip(address indexed ilk, address indexed usr, int256 amt);
    event Flux(address indexed ilk, address indexed usr, address indexed dst, uint256 amt);

    mapping(address => mapping(address => bool)) public can;
    mapping(address => mapping(address => uint256)) public gem;

    function hope(address usr) external {
        can[msg.sender][usr] = true;
        emit Hope(msg.sender, usr);
    }

    function nope(address usr) external {
        can[msg.sender][usr] = false;
        emit Nope(msg.sender, usr);
    }

    function slip(address ilk, address usr, int256 amt) external auth {
        uint256 curr = gem[ilk][usr];
        if (curr > uint256(type(int256).max)) revert Vat__OverUnderFlow();
        int256 next = int256(curr) + amt;
        if (next < 0) revert Vat__OverUnderFlow();
        gem[ilk][usr] = uint256(next);
        emit Slip(ilk, usr, amt);
    }

    function flux(address ilk, address src, address dst, uint256 amt) external {
        if (!wish(src, msg.sender)) revert Vat__NotAuthed();
        uint256 srcNext = gem[ilk][src] - amt;
        uint256 dstNext = gem[ilk][dst] + amt;
        // don't need to validate srcNext because its decreasing
        if (dstNext > uint256(type(int256).max)) revert Vat__OverUnderFlow();
        gem[ilk][src] = srcNext;
        gem[ilk][dst] = dstNext;
        emit Flux(ilk, src, dst, amt);
    }

    function wish(address bit, address usr) internal view returns (bool) {
        return bit == usr || can[bit][usr];
    }
}
