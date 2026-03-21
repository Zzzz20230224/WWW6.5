// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入共享的存储布局，确保代理合约与逻辑合约的变量插槽（Storage Slots）完全对齐
import "./day17_SubscriptionStorageLayout.sol";

/**
 * @title 订阅系统代理合约 (数据主体)
 * @dev 用户直接交互的合约地址。它通过 delegatecall 将指令转发给逻辑合约。
   delegatecall 意味着代码从逻辑合约运行但存储属于代理，所以两者必须共享完全相同的布局。
 * 这样做实现了【逻辑可升级，数据永留存】。
 */
contract SubscriptionStorage is SubscriptionStorageLayout {
    
    /**
     * @notice  权限控制：仅限管理员
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @notice  构造函数：初始化代理
     * @param _logicContract 初始逻辑合约地址（例如 SubscriptionLogicV1 的地址）
     */
    constructor(address _logicContract) {
        owner = msg.sender;          // 部署者成为合约所有者
        logicContract = _logicContract; // 设置第一版功能的实现地址
    }

    /**
     * @notice  逻辑升级函数
     * @dev 将指针指向新的逻辑合约地址。这是实现合约升级的核心，
     * 存储中的用户数据不会丢失，但功能逻辑会瞬间切换到新版本。
     * @param _newLogic 新的逻辑合约地址（例如 SubscriptionLogicV2）
     */
    function upgradeTo(address _newLogic) external onlyOwner {
        logicContract = _newLogic;
    }

    /**
     * @notice  Fallback 函数：底层转发魔法
     * @dev 当用户调用代理合约中不存在的函数（如 subscribe()）时，此函数会被触发。
     * 它通过内联汇编（Assembly）执行 delegatecall，实现透明转发。
     */
    fallback() external payable {
        address impl = logicContract;
        require(impl != address(0), "Logic contract not set");

        // 使用内联汇编以获得最高的执行效率并处理底层返回值
        assembly {
            /**
             * 1. 复制调用数据 (calldatacopy)
             * 将用户发来的所有数据（函数签名 + 参数）从 calldata 复制到内存(memory)中。
             */
            calldatacopy(0, 0, calldatasize())

            /**
             * 2. 执行委托调用 (delegatecall)
             * 调用逻辑合约 (impl) 的代码，但在当前合约 (代理) 的存储上下文中运行。
             * gas(): 转发所有剩余 Gas
             * impl: 逻辑合约地址
             * 0, calldatasize(): 使用内存中刚才复制的数据作为输入
             * 0, 0: 输出由下一步 returndatacopy 处理
             */
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

            /**
             * 3. 复制返回数据 (returndatacopy)
             * 获取逻辑合约执行后的返回值（无论成功还是失败）。
             */
            returndatacopy(0, 0, returndatasize())

            /**
             * 4. 结果处理 (switch)
             * 如果 result 为 0 (表示执行失败/revert)，则将错误信息回滚。
             * 如果执行成功，则将结果返回给原始调用者。
             */
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * @notice 💸 接收函数
     * @dev 允许合约直接接收原始 ETH 转账。
     */
    receive() external payable {}
}