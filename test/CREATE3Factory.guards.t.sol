// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {CREATE3Factory} from "../src/CREATE3Factory.sol";

/// @notice Revert reasons on the deploy path.
/// `CREATE3Factory` itself has no require. Both guards live in solmate `CREATE3`:
/// a CREATE2 that returns the zero address reverts with "DEPLOYMENT_FAILED", and a
/// proxy call that fails or leaves an empty runtime reverts with "INITIALIZATION_FAILED".
/// Any bytes32 salt is accepted, including zero. The salt is hashed with msg.sender,
/// so a collision is per deployer, not global.
contract CREATE3FactoryGuardsTest is Test {
    // solmate CREATE3.PROXY_BYTECODE. The library keeps it internal, so the
    // "proxy already exists" case predicts the CREATE2 address with the same bytes.
    bytes internal constant PROXY_BYTECODE = hex"67363d3d37363d34f03d5260086018f3";

    CREATE3Factory internal factory;

    function setUp() public {
        factory = new CREATE3Factory();
    }

    function test_GetDeployedMatchesDeployedAddress() public {
        bytes32 salt = keccak256("deployed");

        address predicted = factory.getDeployed(address(this), salt);
        address deployed = factory.deploy(salt, type(Dummy).creationCode);

        assertEq(deployed, predicted);
        assertEq(factory.getDeployed(address(this), salt), deployed);
        assertGt(deployed.code.length, 0);
        assertGt(_proxy(address(this), salt).code.length, 0);
        assertEq(Dummy(deployed).ping(), 1);
    }

    function test_ZeroSaltDeploysAndMatchesGetDeployed() public {
        address predicted = factory.getDeployed(address(this), bytes32(0));
        address deployed = factory.deploy(bytes32(0), type(Dummy).creationCode);

        assertEq(deployed, predicted);
        assertGt(deployed.code.length, 0);
    }

    function test_RedeployRevertsWithDeploymentFailed() public {
        bytes32 salt = keccak256("twice");
        address deployed = factory.deploy(salt, type(Dummy).creationCode);

        _expectRevert("DEPLOYMENT_FAILED");
        factory.deploy(salt, type(Dummy).creationCode);

        assertGt(deployed.code.length, 0);
        assertEq(factory.getDeployed(address(this), salt), deployed);
    }

    function test_ExistingProxyRevertsWithDeploymentFailed() public {
        bytes32 salt = keccak256("proxy");
        address proxy = _proxy(address(this), salt);
        address predicted = factory.getDeployed(address(this), salt);

        vm.etch(proxy, hex"00");

        _expectRevert("DEPLOYMENT_FAILED");
        factory.deploy(salt, type(Dummy).creationCode);

        assertEq(predicted.code.length, 0);
    }

    function test_EmptyCreationCodeRevertsWithInitializationFailed() public {
        bytes32 salt = keccak256("empty");
        address predicted = factory.getDeployed(address(this), salt);

        _expectRevert("INITIALIZATION_FAILED");
        factory.deploy(salt, hex"");

        assertEq(predicted.code.length, 0);
        assertEq(_proxy(address(this), salt).code.length, 0);
    }

    function test_RevertingCreationCodeRevertsWithInitializationFailed() public {
        bytes32 salt = keccak256("reverting");
        address predicted = factory.getDeployed(address(this), salt);

        _expectRevert("INITIALIZATION_FAILED");
        factory.deploy(salt, type(Reverting).creationCode);

        assertEq(predicted.code.length, 0);
    }

    function test_ValueOnNonPayableInitRevertsAndSaltStaysFree() public {
        bytes32 salt = keccak256("value");
        vm.deal(address(this), 1 ether);
        uint256 balanceBefore = address(this).balance;

        _expectRevert("INITIALIZATION_FAILED");
        factory.deploy{value: 1 ether}(salt, type(RejectsValue).creationCode);

        assertEq(address(this).balance, balanceBefore);
        assertEq(factory.getDeployed(address(this), salt).code.length, 0);

        address deployed = factory.deploy(salt, type(Dummy).creationCode);
        assertEq(deployed, factory.getDeployed(address(this), salt));
        assertGt(deployed.code.length, 0);
    }

    function test_PayableDeployForwardsValueAndMatchesGetDeployed() public {
        bytes32 salt = keccak256("paid");
        vm.deal(address(this), 1 ether);

        address predicted = factory.getDeployed(address(this), salt);
        address deployed = factory.deploy{value: 1 ether}(salt, type(AcceptsValue).creationCode);

        assertEq(deployed, predicted);
        assertEq(deployed.balance, 1 ether);
        assertEq(address(this).balance, 0);
        assertEq(AcceptsValue(deployed).funded(), 1 ether);
    }

    function test_SameSaltDifferentDeployerSucceeds() public {
        bytes32 salt = keccak256("namespace");
        address first = factory.deploy(salt, type(Dummy).creationCode);

        address other = address(0xBEEF);
        vm.prank(other);
        address second = factory.deploy(salt, type(Dummy).creationCode);

        assertTrue(first != second);
        assertEq(first, factory.getDeployed(address(this), salt));
        assertEq(second, factory.getDeployed(other, salt));
    }

    function _proxy(address deployer, bytes32 salt) internal view returns (address) {
        bytes32 guardedSalt = keccak256(abi.encodePacked(deployer, salt));
        return address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(bytes1(0xff), address(factory), guardedSalt, keccak256(PROXY_BYTECODE)))
                )
            )
        );
    }

    /// Exact `Error(string)` payload. Selector is `keccak256("Error(string)")[:4]` (`0x08c379a0`).
    function _expectRevert(string memory reason) internal {
        bytes memory encoded = abi.encodeWithSignature("Error(string)", reason);
        assertEq(bytes32(bytes4(encoded)), bytes32(bytes4(keccak256("Error(string)"))));
        vm.expectRevert(encoded);
    }
}

contract Dummy {
    function ping() external pure returns (uint256) {
        return 1;
    }
}

contract Reverting {
    constructor() {
        revert();
    }
}

contract RejectsValue {
    constructor() {}
}

contract AcceptsValue {
    constructor() payable {}

    function funded() external view returns (uint256) {
        return address(this).balance;
    }
}
