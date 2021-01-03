pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./Delev.sol";

contract DelevTest is DSTest {
    Delev delev;

    function setUp() public {
        delev = new Delev();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
