// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.26;

contract Auth {
    error Auth__OnlyWards();

    event Rely(address indexed);
    event Deny(address indexed);

    constructor() {
        wards[msg.sender] = true;
        emit Rely(msg.sender);
    }

    // --- Auth ---
    mapping(address => bool) public wards;

    function rely(address usr) external auth {
        wards[usr] = true;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = false;
        emit Deny(usr);
    }

    modifier auth() {
        if (!wards[msg.sender]) revert Auth__OnlyWards();
        _;
    }
}
