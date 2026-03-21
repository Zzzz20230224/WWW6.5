// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./day17_SubscriptionStorageLayout.sol";

/**
 * @title 订阅系统逻辑合约 V2 (升级版)
 * @dev 相比 V1，V2 增加了用户自主管理订阅状态的能力。
 */
contract SubscriptionLogicV2 is SubscriptionStorageLayout {
    
    // --- 继承自 V1 的核心功能 ---

    function addPlan(uint8 planId, uint256 price, uint256 duration) external {
        planPrices[planId] = price;
        planDuration[planId] = duration;
    }

    function subscribe(uint8 planId) external payable {
        require(planPrices[planId] > 0, "Invalid plan");
        require(msg.value >= planPrices[planId], "Insufficient payment");

        Subscription storage s = subscriptions[msg.sender];
        if (block.timestamp < s.expiry) {
            s.expiry += planDuration[planId];
        } else {
            s.expiry = block.timestamp + planDuration[planId];
        }

        s.planId = planId;
        s.paused = false; // 订阅或续费时自动解除暂停
    }

    function isActive(address user) external view returns (bool) {
        Subscription memory s = subscriptions[user];
        // 逻辑增强：只有【未过期】且【未暂停】才算活跃
        return (block.timestamp < s.expiry && !s.paused);
    }

    // --- V2 新增功能：状态控制 ---

    /**
     * @notice 4️⃣ 暂停账户 (pauseAccount)
     * @dev 将用户的订阅状态设为暂停。
     * 🧠 场景：用户最近不出差/不玩游戏，想把账号冻结。
     * 注意：虽然暂停了，但 expiry 时间戳目前仍在流逝（除非你在逻辑中加入时间补偿计算）。
     */
    function pauseAccount(address user) external {
        // 直接修改代理合约存储中的 paused 布尔值
        subscriptions[user].paused = true;
    }

    /**
     * @notice 5️⃣ 恢复账户 (resumeAccount)
     * @dev 解除暂停状态，让用户重新享有权限。
     */
    function resumeAccount(address user) external {
        subscriptions[user].paused = false;
    }
}