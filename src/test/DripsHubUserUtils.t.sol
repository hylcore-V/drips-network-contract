// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {DSTest} from "ds-test/test.sol";
import {DripsHubUser} from "./DripsHubUser.t.sol";
import {SplitsReceiver, DripsHub, DripsReceiver} from "../DripsHub.sol";

abstract contract DripsHubUserUtils is DSTest {
    uint256 internal defaultAsset;

    // Keys are user and asset ID
    mapping(DripsHubUser => mapping(uint256 => bytes)) internal drips;
    // Keys are user, account ID and asset ID
    mapping(DripsHubUser => mapping(uint256 => mapping(uint256 => bytes))) internal accountDrips;
    mapping(DripsHubUser => bytes) internal currSplitsReceivers;

    function loadDrips(DripsHubUser user)
        internal
        returns (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory currReceivers
        )
    {
        return loadDrips(defaultAsset, user);
    }

    function loadDrips(uint256 asset, DripsHubUser user)
        internal
        returns (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory currReceivers
        )
    {
        (lastUpdate, lastBalance, currReceivers) = decodeDrips(drips[user][asset]);
        assertDrips(asset, user, lastUpdate, lastBalance, currReceivers);
    }

    function loadDrips(DripsHubUser user, uint256 account)
        internal
        returns (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory currReceivers
        )
    {
        return loadDrips(defaultAsset, user, account);
    }

    function loadDrips(
        uint256 asset,
        DripsHubUser user,
        uint256 account
    )
        internal
        returns (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory currReceivers
        )
    {
        (lastUpdate, lastBalance, currReceivers) = decodeDrips(accountDrips[user][account][asset]);
        assertDrips(asset, user, account, lastUpdate, lastBalance, currReceivers);
    }

    function storeDrips(
        DripsHubUser user,
        uint128 newBalance,
        DripsReceiver[] memory newReceivers
    ) internal {
        storeDrips(defaultAsset, user, newBalance, newReceivers);
    }

    function storeDrips(
        uint256 asset,
        DripsHubUser user,
        uint128 newBalance,
        DripsReceiver[] memory newReceivers
    ) internal {
        uint64 currTimestamp = uint64(block.timestamp);
        assertDrips(asset, user, currTimestamp, newBalance, newReceivers);
        drips[user][asset] = abi.encode(currTimestamp, newBalance, newReceivers);
    }

    function storeDrips(
        DripsHubUser user,
        uint256 account,
        uint128 newBalance,
        DripsReceiver[] memory newReceivers
    ) internal {
        storeDrips(defaultAsset, user, account, newBalance, newReceivers);
    }

    function storeDrips(
        uint256 asset,
        DripsHubUser user,
        uint256 account,
        uint128 newBalance,
        DripsReceiver[] memory newReceivers
    ) internal {
        uint64 currTimestamp = uint64(block.timestamp);
        assertDrips(asset, user, account, currTimestamp, newBalance, newReceivers);
        accountDrips[user][account][asset] = abi.encode(currTimestamp, newBalance, newReceivers);
    }

    function decodeDrips(bytes storage encoded)
        internal
        view
        returns (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory
        )
    {
        if (encoded.length == 0) {
            return (0, 0, new DripsReceiver[](0));
        } else {
            return abi.decode(encoded, (uint64, uint128, DripsReceiver[]));
        }
    }

    function getCurrSplitsReceivers(DripsHubUser user)
        internal
        view
        returns (SplitsReceiver[] memory)
    {
        bytes storage encoded = currSplitsReceivers[user];
        if (encoded.length == 0) {
            return new SplitsReceiver[](0);
        } else {
            return abi.decode(encoded, (SplitsReceiver[]));
        }
    }

    function setCurrSplitsReceivers(DripsHubUser user, SplitsReceiver[] memory newReceivers)
        internal
    {
        currSplitsReceivers[user] = abi.encode(newReceivers);
    }

    function dripsReceivers() internal pure returns (DripsReceiver[] memory list) {
        list = new DripsReceiver[](0);
    }

    function dripsReceivers(DripsHubUser user, uint128 amtPerSec)
        internal
        pure
        returns (DripsReceiver[] memory list)
    {
        list = new DripsReceiver[](1);
        list[0] = DripsReceiver(address(user), amtPerSec);
    }

    function dripsReceivers(
        DripsHubUser user1,
        uint128 amtPerSec1,
        DripsHubUser user2,
        uint128 amtPerSec2
    ) internal pure returns (DripsReceiver[] memory list) {
        list = new DripsReceiver[](2);
        list[0] = DripsReceiver(address(user1), amtPerSec1);
        list[1] = DripsReceiver(address(user2), amtPerSec2);
    }

    function setDrips(
        DripsHubUser user,
        uint128 balanceFrom,
        uint128 balanceTo,
        DripsReceiver[] memory newReceivers
    ) internal {
        setDrips(defaultAsset, user, balanceFrom, balanceTo, newReceivers);
    }

    function setDrips(
        uint256 asset,
        DripsHubUser user,
        uint128 balanceFrom,
        uint128 balanceTo,
        DripsReceiver[] memory newReceivers
    ) internal {
        int128 balanceDelta = int128(balanceTo) - int128(balanceFrom);
        uint256 expectedBalance = uint256(int256(user.balance(asset)) - balanceDelta);
        (uint64 lastUpdate, uint128 lastBalance, DripsReceiver[] memory currReceivers) = loadDrips(
            asset,
            user
        );

        (uint128 newBalance, int128 realBalanceDelta) = user.setDrips(
            asset,
            lastUpdate,
            lastBalance,
            currReceivers,
            balanceDelta,
            newReceivers
        );

        storeDrips(asset, user, newBalance, newReceivers);
        assertEq(newBalance, balanceTo, "Invalid drips balance");
        assertEq(realBalanceDelta, balanceDelta, "Invalid real balance delta");
        assertBalance(asset, user, expectedBalance);
    }

    function assertDrips(
        uint256 asset,
        DripsHubUser user,
        uint64 lastUpdate,
        uint128 balance,
        DripsReceiver[] memory currReceivers
    ) internal {
        bytes32 actual = user.dripsHash(asset);
        bytes32 expected = user.hashDrips(lastUpdate, balance, currReceivers);
        assertEq(actual, expected, "Invalid drips configuration");
    }

    function assertDripsBalance(DripsHubUser user, uint128 expected) internal {
        changeBalance(user, expected, expected);
    }

    function changeBalance(
        DripsHubUser user,
        uint128 balanceFrom,
        uint128 balanceTo
    ) internal {
        (, , DripsReceiver[] memory currReceivers) = loadDrips(user);
        setDrips(user, balanceFrom, balanceTo, currReceivers);
    }

    function assertSetReceiversReverts(
        DripsHubUser user,
        DripsReceiver[] memory newReceivers,
        string memory expectedReason
    ) internal {
        (uint64 lastUpdate, uint128 lastBalance, DripsReceiver[] memory currReceivers) = loadDrips(
            user
        );
        assertSetDripsReverts(
            user,
            lastUpdate,
            lastBalance,
            currReceivers,
            0,
            newReceivers,
            expectedReason
        );
    }

    function assertSetDripsReverts(
        DripsHubUser user,
        uint64 lastUpdate,
        uint128 lastBalance,
        DripsReceiver[] memory currReceivers,
        int128 balanceDelta,
        DripsReceiver[] memory newReceivers,
        string memory expectedReason
    ) internal {
        try
            user.setDrips(
                defaultAsset,
                lastUpdate,
                lastBalance,
                currReceivers,
                balanceDelta,
                newReceivers
            )
        {
            assertTrue(false, "Set drips hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, expectedReason, "Invalid set drips revert reason");
        }
    }

    function setDrips(
        DripsHubUser user,
        uint256 account,
        uint128 balanceFrom,
        uint128 balanceTo,
        DripsReceiver[] memory newReceivers
    ) internal {
        int128 balanceDelta = int128(balanceTo) - int128(balanceFrom);
        uint256 expectedBalance = uint256(int256(user.balance(defaultAsset)) - balanceDelta);
        (uint64 lastUpdate, uint128 lastBalance, DripsReceiver[] memory currReceivers) = loadDrips(
            user,
            account
        );

        (uint128 newBalance, int128 realBalanceDelta) = user.setDrips(
            account,
            defaultAsset,
            lastUpdate,
            lastBalance,
            currReceivers,
            balanceDelta,
            newReceivers
        );

        storeDrips(user, account, newBalance, newReceivers);
        assertEq(newBalance, balanceTo, "Invalid drips balance");
        assertEq(realBalanceDelta, balanceDelta, "Invalid real balance delta");
        assertBalance(user, expectedBalance);
    }

    function assertDrips(
        uint256 asset,
        DripsHubUser user,
        uint256 account,
        uint64 lastUpdate,
        uint128 lastBalance,
        DripsReceiver[] memory currReceivers
    ) internal {
        bytes32 actual = user.dripsHash(account, asset);
        bytes32 expected = user.hashDrips(lastUpdate, lastBalance, currReceivers);
        assertEq(actual, expected, "Invalid drips configuration");
    }

    function changeBalance(
        DripsHubUser user,
        uint256 account,
        uint128 balanceFrom,
        uint128 balanceTo
    ) internal {
        (, , DripsReceiver[] memory curr) = loadDrips(user, account);
        setDrips(user, account, balanceFrom, balanceTo, curr);
    }

    function give(
        DripsHubUser user,
        DripsHubUser receiver,
        uint128 amt
    ) internal {
        give(defaultAsset, user, receiver, amt);
    }

    function give(
        uint256 asset,
        DripsHubUser user,
        DripsHubUser receiver,
        uint128 amt
    ) internal {
        uint256 expectedBalance = uint256(user.balance(asset) - amt);
        uint128 expectedCollectable = totalCollectableAll(asset, receiver) + amt;

        user.give(address(receiver), asset, amt);

        assertBalance(asset, user, expectedBalance);
        assertTotalCollectableAll(asset, receiver, expectedCollectable);
    }

    function give(
        DripsHubUser user,
        uint256 account,
        DripsHubUser receiver,
        uint128 amt
    ) internal {
        uint256 expectedBalance = uint256(user.balance(defaultAsset) - amt);
        uint128 expectedCollectable = totalCollectableAll(defaultAsset, receiver) + amt;

        user.give(account, address(receiver), defaultAsset, amt);

        assertBalance(defaultAsset, user, expectedBalance);
        assertTotalCollectableAll(defaultAsset, receiver, expectedCollectable);
    }

    function splitsReceivers() internal pure returns (SplitsReceiver[] memory list) {
        list = new SplitsReceiver[](0);
    }

    function splitsReceivers(DripsHubUser user, uint32 weight)
        internal
        pure
        returns (SplitsReceiver[] memory list)
    {
        list = new SplitsReceiver[](1);
        list[0] = SplitsReceiver(address(user), weight);
    }

    function splitsReceivers(
        DripsHubUser user1,
        uint32 weight1,
        DripsHubUser user2,
        uint32 weight2
    ) internal pure returns (SplitsReceiver[] memory list) {
        list = new SplitsReceiver[](2);
        list[0] = SplitsReceiver(address(user1), weight1);
        list[1] = SplitsReceiver(address(user2), weight2);
    }

    function setSplits(DripsHubUser user, SplitsReceiver[] memory newReceivers) internal {
        SplitsReceiver[] memory curr = getCurrSplitsReceivers(user);
        assertSplits(user, curr);

        user.setSplits(newReceivers);

        setCurrSplitsReceivers(user, newReceivers);
        assertSplits(user, newReceivers);
    }

    function assertSetSplitsReverts(
        DripsHubUser user,
        SplitsReceiver[] memory newReceivers,
        string memory expectedReason
    ) internal {
        SplitsReceiver[] memory curr = getCurrSplitsReceivers(user);
        assertSplits(user, curr);
        try user.setSplits(newReceivers) {
            assertTrue(false, "setSplits hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, expectedReason, "Invalid setSplits revert reason");
        }
    }

    function assertSplits(DripsHubUser user, SplitsReceiver[] memory expectedReceivers) internal {
        bytes32 actual = user.splitsHash();
        bytes32 expected = user.hashSplits(expectedReceivers);
        assertEq(actual, expected, "Invalid splits hash");
    }

    function collectAll(DripsHubUser user, uint128 expectedAmt) internal {
        collectAll(defaultAsset, user, user, expectedAmt, 0);
    }

    function collectAll(
        uint256 asset,
        DripsHubUser user,
        uint128 expectedAmt
    ) internal {
        collectAll(asset, user, user, expectedAmt, 0);
    }

    function collectAll(
        DripsHubUser user,
        uint128 expectedCollected,
        uint128 expectedSplit
    ) internal {
        collectAll(defaultAsset, user, user, expectedCollected, expectedSplit);
    }

    function collectAll(
        uint256 asset,
        DripsHubUser user,
        uint128 expectedCollected,
        uint128 expectedSplit
    ) internal {
        collectAll(asset, user, user, expectedCollected, expectedSplit);
    }

    function collectAll(
        DripsHubUser user,
        DripsHubUser collected,
        uint128 expectedAmt
    ) internal {
        collectAll(defaultAsset, user, collected, expectedAmt, 0);
    }

    function collectAll(
        uint256 asset,
        DripsHubUser user,
        DripsHubUser collected,
        uint128 expectedCollected,
        uint128 expectedSplit
    ) internal {
        assertCollectableAll(asset, collected, expectedCollected, expectedSplit);
        uint256 expectedBalance = collected.balance(asset) + expectedCollected;

        (uint128 collectedAmt, uint128 splitAmt) = user.collectAll(
            address(collected),
            asset,
            getCurrSplitsReceivers(user)
        );

        assertEq(collectedAmt, expectedCollected, "Invalid collected amount");
        assertEq(splitAmt, expectedSplit, "Invalid split amount");
        assertCollectableAll(asset, collected, 0);
        assertBalance(asset, collected, expectedBalance);
    }

    function assertCollectableAll(DripsHubUser user, uint128 expected) internal {
        assertCollectableAll(defaultAsset, user, expected, 0);
    }

    function assertCollectableAll(
        uint256 asset,
        DripsHubUser user,
        uint128 expected
    ) internal {
        assertCollectableAll(asset, user, expected, 0);
    }

    function assertCollectableAll(
        DripsHubUser user,
        uint128 expectedCollected,
        uint128 expectedSplit
    ) internal {
        assertCollectableAll(defaultAsset, user, expectedCollected, expectedSplit);
    }

    function assertCollectableAll(
        uint256 asset,
        DripsHubUser user,
        uint128 expectedCollected,
        uint128 expectedSplit
    ) internal {
        (uint128 actualCollected, uint128 actualSplit) = user.collectableAll(
            asset,
            getCurrSplitsReceivers(user)
        );
        assertEq(actualCollected, expectedCollected, "Invalid collected");
        assertEq(actualSplit, expectedSplit, "Invalid split");
    }

    function totalCollectableAll(uint256 asset, DripsHubUser user) internal view returns (uint128) {
        SplitsReceiver[] memory splits = getCurrSplitsReceivers(user);
        (uint128 collectableAmt, uint128 splittableAmt) = user.collectableAll(asset, splits);
        return collectableAmt + splittableAmt;
    }

    function assertTotalCollectableAll(
        uint256 asset,
        DripsHubUser user,
        uint128 expectedCollectable
    ) internal {
        uint128 actualCollectable = totalCollectableAll(asset, user);
        assertEq(actualCollectable, expectedCollectable, "Invalid total collectable");
    }

    function receiveDrips(
        DripsHubUser user,
        uint128 expectedReceivedAmt,
        uint64 expectedReceivedCycles
    ) internal {
        receiveDrips(user, type(uint64).max, expectedReceivedAmt, expectedReceivedCycles, 0, 0);
    }

    function receiveDrips(
        DripsHubUser user,
        uint64 maxCycles,
        uint128 expectedReceivedAmt,
        uint64 expectedReceivedCycles,
        uint128 expectedAmtAfter,
        uint64 expectedCyclesAfter
    ) internal {
        uint128 expectedTotalAmt = expectedReceivedAmt + expectedAmtAfter;
        uint64 expectedTotalCycles = expectedReceivedCycles + expectedCyclesAfter;
        assertReceivableDripsCycles(user, expectedTotalCycles);
        assertReceivableDrips(user, type(uint64).max, expectedTotalAmt, 0);
        assertReceivableDrips(user, maxCycles, expectedReceivedAmt, expectedCyclesAfter);

        (uint128 receivedAmt, uint64 receivableCycles) = user.receiveDrips(defaultAsset, maxCycles);

        assertEq(receivedAmt, expectedReceivedAmt, "Invalid amount received from drips");
        assertEq(receivableCycles, expectedCyclesAfter, "Invalid receivable drips cycles left");
        assertReceivableDripsCycles(user, expectedCyclesAfter);
        assertReceivableDrips(user, type(uint64).max, expectedAmtAfter, 0);
    }

    function assertReceivableDripsCycles(DripsHubUser user, uint64 expectedCycles) internal {
        uint64 actualCycles = user.receivableDripsCycles(defaultAsset);
        assertEq(actualCycles, expectedCycles, "Invalid total receivable drips cycles");
    }

    function assertReceivableDrips(
        DripsHubUser user,
        uint64 maxCycles,
        uint128 expectedAmt,
        uint64 expectedCycles
    ) internal {
        (uint128 actualAmt, uint64 actualCycles) = user.receivableDrips(defaultAsset, maxCycles);
        assertEq(actualAmt, expectedAmt, "Invalid receivable amount");
        assertEq(actualCycles, expectedCycles, "Invalid receivable drips cycles");
    }

    function split(
        DripsHubUser user,
        uint128 expectedCollectable,
        uint128 expectedSplit
    ) internal {
        assertSplittable(user, expectedCollectable + expectedSplit);
        uint128 collectableBefore = collectable(user);

        (uint128 collectableAmt, uint128 splitAmt) = user.split(
            address(user),
            defaultAsset,
            getCurrSplitsReceivers(user)
        );

        assertEq(collectableAmt, expectedCollectable, "Invalid collectable amount");
        assertEq(splitAmt, expectedSplit, "Invalid split amount");
        assertSplittable(user, 0);
        assertCollectable(user, collectableBefore + expectedCollectable);
    }

    function assertSplittable(DripsHubUser user, uint256 expected) internal {
        assertEq(user.splittable(address(user), defaultAsset), expected, "Invalid splittable");
    }

    function collect(DripsHubUser user, uint128 expectedAmt) internal {
        assertCollectable(user, expectedAmt);
        uint256 balanceBefore = user.balance(defaultAsset);

        uint128 actualAmt = user.collect(address(user), defaultAsset);

        assertEq(actualAmt, expectedAmt, "Invalid collected amount");
        assertCollectable(user, 0);
        assertBalance(user, balanceBefore + expectedAmt);
    }

    function collectable(DripsHubUser user) internal view returns (uint128 amt) {
        return user.collectable(address(user), defaultAsset);
    }

    function assertCollectable(DripsHubUser user, uint256 expected) internal {
        assertEq(collectable(user), expected, "Invalid collectable");
    }

    function assertBalance(DripsHubUser user, uint256 expected) internal {
        assertBalance(defaultAsset, user, expected);
    }

    function assertBalance(
        uint256 asset,
        DripsHubUser user,
        uint256 expected
    ) internal {
        assertEq(user.balance(asset), expected, "Invalid balance");
    }
}
