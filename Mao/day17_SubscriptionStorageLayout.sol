// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 订阅系统存储布局 (蓝图合约)
 * @dev 这是一个独立的存储合约，不包含业务函数。
 * 它的核心思想是将【存储】与【逻辑】分离，这是代理升级模式（Proxy Pattern）的关键。
 * 代理合约和逻辑合约都必须继承此布局，以确保 delegatecall 时的内存结构完全对齐。
 */
contract SubscriptionStorageLayout {

    /**
     * @notice 🔑 logicContract (实现合约地址)
     * @dev 存储当前实际运行功能的逻辑合约地址。
     * 代理合约通过此地址知道将调用转发（delegatecall）到哪里。
     * 后续可以通过升级函数更新此地址以切换版本。
     */
    address public logicContract;

    /**
     * @notice 👑 owner (管理员)
     * @dev 记录合约的部署者或管理员。
     * 只有此地址有权执行升级操作（修改 logicContract）。
     */
    address public owner;

    /**
     * @notice 📦 Subscription 结构体
     * @dev 定义了单个用户订阅的核心数据维度。
     */
    struct Subscription {
        // 用户套餐标识符 (如 1:基础版, 2:专业版, 3:高级版)
        // 使用 uint8 而非 uint256 是为了在结构体紧凑布局时节省 Gas
        uint8 planId;      
        
        // 订阅到期的 Unix 时间戳
        // 使用 uint256 确保可以容纳远期的秒数
        uint256 expiry;    
        
        // 开关变量：用于在不删除数据的情况下临时停用订阅
        // 允许用户在不使用服务时“冻结”时间
        bool paused;       
    }

    /**
     * @notice 核心映射 (数据索引)
     */

    // 每个玩家地址 (address) 对应一个自己的 Subscription 对象
    // 用于追踪所有用户的实时套餐状态、到期时间和暂停状态
    mapping(address => Subscription) public subscriptions;

    // 定价表：套餐 ID (uint8) => 所需支付的 ETH (uint256)
    // 例如：planPrices[1] = 0.01 ether
    mapping(uint8 => uint256) public planPrices;

    // 时长表：套餐 ID (uint8) => 持续时长秒数 (uint256)
    // 例如：planDuration[1] = 30 days
    mapping(uint8 => uint256) public planDuration;
}