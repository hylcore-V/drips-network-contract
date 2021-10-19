// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.7;

import {EthPool, Pool} from "../EthPool.sol";
import {ERC20Pool, ReceiverWeight} from "../DaiPool.sol";

abstract contract PoolUser {
    function getPool() internal view virtual returns (Pool);

    function balance() public view virtual returns (uint256);

    function getAmtPerSecUnchanged() public view returns (uint128) {
        return getPool().AMT_PER_SEC_UNCHANGED();
    }

    function getDripsFractionMax() public view returns (uint32) {
        return getPool().DRIPS_FRACTION_MAX();
    }

    function updateSender(
        uint128 toppedUp,
        uint128 withdraw,
        uint128 amtPerSec,
        uint32 dripsFraction,
        ReceiverWeight[] calldata currReceivers,
        ReceiverWeight[] calldata newReceivers
    )
        public
        virtual
        returns (
            uint128 withdrawn,
            uint128 collected,
            uint128 dripped
        );

    function updateSubSender(
        uint256 subSenderId,
        uint128 toppedUp,
        uint128 withdraw,
        uint128 amtPerSec,
        ReceiverWeight[] calldata currReceivers,
        ReceiverWeight[] calldata newReceivers
    ) public virtual returns (uint128 withdrawn);

    function collect(address receiverAddr, ReceiverWeight[] calldata currReceivers)
        public
        returns (uint128 collected, uint128 dripped)
    {
        return getPool().collect(receiverAddr, currReceivers);
    }

    function collectable() public view returns (uint128 collected, uint128 dripped) {
        return getPool().collectable(address(this));
    }

    function flushableCycles() public view returns (uint64 flushable) {
        return getPool().flushableCycles(address(this));
    }

    function flushCycles(uint64 maxCycles) public returns (uint64 flushable) {
        return getPool().flushCycles(address(this), maxCycles);
    }

    function withdrawable() public view returns (uint128) {
        return getPool().withdrawable(address(this));
    }

    function withdrawableSubSender(uint256 subSenderId) public view returns (uint128) {
        return getPool().withdrawableSubSender(address(this), subSenderId);
    }

    function getAmtPerSec() public view returns (uint128) {
        return getPool().getAmtPerSec(address(this));
    }

    function getAmtPerSecSubSender(uint256 subSenderId) public view returns (uint128) {
        return getPool().getAmtPerSecSubSender(address(this), subSenderId);
    }

    function getDripsFraction() public view returns (uint32) {
        return getPool().getDripsFraction(address(this));
    }

    function getAllReceivers() public view returns (ReceiverWeight[] memory weights) {
        return getPool().getAllReceivers(address(this));
    }

    function getAllReceiversSubSender(uint256 subSenderId)
        public
        view
        returns (ReceiverWeight[] memory weights)
    {
        return getPool().getAllReceiversSubSender(address(this), subSenderId);
    }
}

contract ERC20PoolUser is PoolUser {
    ERC20Pool internal immutable pool;

    constructor(ERC20Pool pool_) {
        pool = pool_;
    }

    function getPool() internal view override returns (Pool) {
        return Pool(pool);
    }

    function balance() public view override returns (uint256) {
        return pool.erc20().balanceOf(address(this));
    }

    function updateSender(
        uint128 toppedUp,
        uint128 withdraw,
        uint128 amtPerSec,
        uint32 dripsFraction,
        ReceiverWeight[] calldata currReceivers,
        ReceiverWeight[] calldata newReceivers
    )
        public
        override
        returns (
            uint128 withdrawn,
            uint128 collected,
            uint128 dripped
        )
    {
        pool.erc20().approve(address(pool), toppedUp);
        return
            pool.updateSender(
                toppedUp,
                withdraw,
                amtPerSec,
                dripsFraction,
                currReceivers,
                newReceivers
            );
    }

    function updateSubSender(
        uint256 subSenderId,
        uint128 toppedUp,
        uint128 withdraw,
        uint128 amtPerSec,
        ReceiverWeight[] calldata currReceivers,
        ReceiverWeight[] calldata newReceivers
    ) public override returns (uint128 withdrawn) {
        pool.erc20().approve(address(pool), toppedUp);
        return
            pool.updateSubSender(
                subSenderId,
                toppedUp,
                withdraw,
                amtPerSec,
                currReceivers,
                newReceivers
            );
    }
}

contract EthPoolUser is PoolUser {
    EthPool internal immutable pool;

    constructor(EthPool pool_) payable {
        pool = pool_;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function getPool() internal view override returns (Pool) {
        return Pool(pool);
    }

    function balance() public view override returns (uint256) {
        return address(this).balance;
    }

    function updateSender(
        uint128 toppedUp,
        uint128 withdraw,
        uint128 amtPerSec,
        uint32 dripsFraction,
        ReceiverWeight[] calldata currReceivers,
        ReceiverWeight[] calldata newReceivers
    )
        public
        override
        returns (
            uint128 withdrawn,
            uint128 collected,
            uint128 dripped
        )
    {
        return
            pool.updateSender{value: toppedUp}(
                withdraw,
                amtPerSec,
                dripsFraction,
                currReceivers,
                newReceivers
            );
    }

    function updateSubSender(
        uint256 subSenderId,
        uint128 toppedUp,
        uint128 withdraw,
        uint128 amtPerSec,
        ReceiverWeight[] calldata currReceivers,
        ReceiverWeight[] calldata newReceivers
    ) public override returns (uint128 withdrawn) {
        return
            pool.updateSubSender{value: toppedUp}(
                subSenderId,
                withdraw,
                amtPerSec,
                currReceivers,
                newReceivers
            );
    }
}
