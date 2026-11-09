// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {CREATE3Factory} from "../src/CREATE3Factory.sol";
import {DeployScript} from "../script/Deploy.s.sol";

/// @notice End-to-end checks of the property this factory is deployed for.
/// Child addresses follow the factory address, the deployer, and the salt.
/// Chain id and constructor arguments do not. The CREATE3 proxy, not the
/// caller, is msg.sender in the child constructor, and a later call to that
/// proxy must not replace the child.
contract CREATE3FactoryE2ETest is Test {
    bytes32 internal constant SALT = keccak256("e2e");

    function test_SameChildAddressAcrossChainsWithDifferentArgs() public {
        uint256 snap = VmState(address(vm)).snapshotState();

        vm.chainId(1);
        CREATE3Factory mainnet = new CREATE3Factory();
        address factoryAddr = address(mainnet);
        address predicted = mainnet.getDeployed(address(this), SALT);
        address child = mainnet.deploy(SALT, abi.encodePacked(type(Configured).creationCode, abi.encode(uint256(1))));

        assertEq(child, predicted);
        assertEq(Configured(child).arg(), 1);
        assertEq(block.chainid, 1);

        assertTrue(VmState(address(vm)).revertToState(snap));

        vm.chainId(10);
        CREATE3Factory optimism = new CREATE3Factory();
        assertEq(address(optimism), factoryAddr);
        assertEq(block.chainid, 10);

        address childAgain =
            optimism.deploy(SALT, abi.encodePacked(type(Configured).creationCode, abi.encode(uint256(2))));

        assertEq(childAgain, child);
        assertEq(optimism.getDeployed(address(this), SALT), childAgain);
        assertEq(Configured(childAgain).arg(), 2);
    }

    function test_DifferentFactoryAddressChangesChildAddress() public {
        CREATE3Factory first = new CREATE3Factory();
        CREATE3Factory second = new CREATE3Factory();
        assertTrue(address(first) != address(second));

        bytes memory creationCode = abi.encodePacked(type(Configured).creationCode, abi.encode(uint256(1)));
        address childA = first.deploy(SALT, creationCode);
        address childB = second.deploy(SALT, creationCode);

        assertTrue(childA != childB);
        assertEq(Configured(childA).arg(), 1);
        assertEq(Configured(childB).arg(), 1);
        assertEq(childA, first.getDeployed(address(this), SALT));
        assertEq(childB, second.getDeployed(address(this), SALT));
    }

    function test_ProxyCallerIsNotReplacedByALaterCreate() public {
        CREATE3Factory factory = new CREATE3Factory();
        address child = factory.deploy(SALT, abi.encodePacked(type(Configured).creationCode, abi.encode(uint256(7))));
        address proxy = Configured(child).createdBy();

        assertTrue(proxy != address(this));
        assertTrue(proxy != address(factory));
        assertGt(proxy.code.length, 0);

        (bool ok,) = proxy.call(abi.encodePacked(type(Configured).creationCode, abi.encode(uint256(9))));
        assertTrue(ok);

        assertEq(Configured(child).arg(), 7);
        assertEq(factory.getDeployed(address(this), SALT), child);
        assertGt(child.code.length, 0);
    }

    function test_DeployScriptFactoryDeploysAndThenRejectsARepeat() public {
        vm.setEnv("PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
        CREATE3Factory factory = new DeployScript().run();
        assertGt(address(factory).code.length, 0);

        address predicted = factory.getDeployed(address(this), SALT);
        address child = factory.deploy(SALT, abi.encodePacked(type(Configured).creationCode, abi.encode(uint256(4))));
        assertEq(child, predicted);
        assertEq(Configured(child).arg(), 4);

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "DEPLOYMENT_FAILED"));
        factory.deploy(SALT, abi.encodePacked(type(Configured).creationCode, abi.encode(uint256(5))));

        assertEq(Configured(child).arg(), 4);
        assertEq(factory.getDeployed(address(this), SALT), child);
    }
}

interface VmState {
    function snapshotState() external returns (uint256);
    function revertToState(uint256 id) external returns (bool);
}

contract Configured {
    uint256 public immutable arg;
    address public immutable createdBy;

    constructor(uint256 arg_) {
        arg = arg_;
        createdBy = msg.sender;
    }
}
