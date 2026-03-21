// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入完全相同的存储布局。
// 必须确保逻辑合约与代理合约（SubscriptionStorage）的内存插槽顺序 100% 一致。
import "./day17_SubscriptionStorageLayout.sol";

/**
 * @title 订阅系统逻辑合约 V1
 * @dev 这是系统的“大脑”。它不直接持有资金或数据，而是通过 delegatecall 在代理合约的上下文中运行。
 */
contract SubscriptionLogicV1 is SubscriptionStorageLayout {

    /**
     * @notice 1️⃣ 添加或更新订阅套餐 (addPlan)
     * @dev 允许管理员定义不同的定价层级。
     * @param planId 套餐唯一标识 (如 1:月卡, 2:年卡)
     * @param price 套餐价格 (单位: wei)
     * @param duration 持续时长 (单位: 秒，如 30 days)
     */
    function addPlan(uint8 planId, uint256 price, uint256 duration) external {
        // 在代理合约的存储中记录价格和时长
        planPrices[planId] = price;
        planDuration[planId] = duration;
        
        // 🧠 为什么这有用：
        // 这种设计让订阅系统高度可定制。你可以随时增加 Plan 3、Plan 4，
        // 而不需要重新部署核心逻辑。
    }

    /**
     * @notice 2️⃣ 用户订阅/续费 (subscribe)
     * @dev 处理用户支付 ETH 并更新其到期时间的逻辑。
     * @param planId 用户想要购买的套餐 ID
     */
    function subscribe(uint8 planId) external payable {
        // 安全检查：确保套餐存在且用户支付了足够的金额
        require(planPrices[planId] > 0, "Invalid plan");
        require(msg.value >= planPrices[planId], "Insufficient payment");

        // 使用 'storage' 指针直接指向代理合约中的用户记录
        Subscription storage s = subscriptions[msg.sender];

        /**
         * 📦 处理两种订阅场景：
         * 情况 A：用户当前订阅尚未过期 (block.timestamp < s.expiry)
         * -> 在原有到期时间基础上累加时长（续费模式）。
         * 情况 B：用户没有订阅或已过期
         * -> 从当前区块时间开始计算新的到期时间（新购模式）。
         */
        if (block.timestamp < s.expiry) {
            s.expiry += planDuration[planId];
        } else {
            s.expiry = block.timestamp + planDuration[planId];
        }

        // 更新记录：保存用户选择的套餐 ID，并确保没有处于暂停状态
        s.planId = planId;
        s.paused = false;

        // 🧠 为什么这很聪明：
        // 它用一个函数同时解决了“新购”、“续费”和“恢复订阅”三个逻辑，极大地节省了 Gas。
    }

    /**
     * @notice 3️⃣ 订阅状态查询 (isActive)
     * @dev 只读函数，用于判断用户当前是否享有会员权限。
     * @param user 要查询的玩家地址
     * @return 返回 true 表示订阅有效（未过期且未暂停）
     */
    function isActive(address user) external view returns (bool) {
        // 使用 'memory' 因为我们只需要读取数据进行计算，不需要修改存储
        Subscription memory s = subscriptions[user];

        // 核心判断逻辑：当前时间必须小于到期时间，且 paused 开关为 false
        return (block.timestamp < s.expiry && !s.paused);

        // 📌 为什么这很重要：
        // 这是游戏前端或其他功能合约（如 VIP 商店）判断权限的唯一标准。
    }
}