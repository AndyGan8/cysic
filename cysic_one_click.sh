#!/bin/bash

# 一键脚本用于设置和运行Cysic验证程序，包含主菜单

# 函数：安装并运行节点
install_and_run_node() {
    # 提示用户输入奖励地址
    echo "请输入您的奖励地址（以 0x 开头）："
    read -r REWARD_ADDRESS

    # 检查是否提供了奖励地址
    if [ -z "$REWARD_ADDRESS" ]; then
        echo "错误：奖励地址不能为空。"
        return 1
    fi

    echo "正在使用奖励地址 $REWARD_ADDRESS 下载并运行安装脚本..."
    curl -L https://github.com/cysic-labs/cysic-phase3/releases/download/v1.0.0/setup_linux.sh > ~/setup_linux.sh
    if [ $? -ne 0 ]; then
        echo "错误：无法下载安装脚本。请检查网络连接或URL。"
        return 1
    fi

    bash ~/setup_linux.sh "$REWARD_ADDRESS"
    if [ $? -ne 0 ]; then
        echo "错误：安装脚本执行失败。请检查错误信息。"
        return 1
    fi

    echo "等待安装完成，启动验证程序..."
    sleep 10  # 等待安装完成，时间可根据需要调整
    cd ~/cysic-verifier/ || { echo "错误：无法切换到~/cysic-verifier/目录"; return 1; }
    
    # 在新的 screen 会话中启动验证程序
    screen -dmS cysic_verifier bash start.sh
    if [ $? -ne 0 ]; then
        echo "错误：启动验证程序失败。请检查start.sh脚本或等待几分钟后重试。"
        echo "如果看到'err: rpc error'，请等待几分钟，验证程序将尝试连接。"
    else
        echo "验证程序已在 screen 会话 'cysic_verifier' 中启动！"
        echo "您可以使用选项 2 查看 screen 日志，或运行 'screen -r cysic_verifier' 直接进入会话。"
        echo "重要：您的助记词文件已生成，位于 ~/.cysic/keys/ 文件夹。"
        echo "请妥善备份此文件夹中的文件，否则您将无法再次运行验证程序。"
    fi
}

# 函数：查看 screen 日志
view_logs() {
    # 检查 screen 会话是否存在
    if screen -list | grep -q "cysic_verifier"; then
        echo "找到 screen 会话 'cysic_verifier'。"
        echo "您可以直接进入 screen 会话查看实时日志，命令为：screen -r cysic_verifier"
        echo "按 Ctrl+A 然后按 D 退出 screen 会话而不终止程序。"
        echo "是否要进入 screen 会话查看日志？（y/n）"
        read -r enter_screen
        if [ "$enter_screen" = "y" ] || [ "$enter_screen" = "Y" ]; then
            screen -r cysic_verifier
        else
            echo "您选择了不进入 screen 会话。可以通过 'screen -r cysic_verifier' 随时查看。"
        fi
    else
        echo "错误：未找到 screen 会话 'cysic_verifier'。"
        echo "请确保已通过选项 1 启动验证程序，或检查 screen 会话是否已被终止。"
        echo "您可以运行 'screen -list' 查看所有活动 screen 会话。"
    fi
}

# 函数：重新连接验证程序
reconnect_verifier() {
    echo "正在尝试重新连接验证程序..."
    # 检查是否已有 screen 会话
    if screen -list | grep -q "cysic_verifier"; then
        echo "已有运行中的 screen 会话 'cysic_verifier'。"
        echo "是否要终止现有会话并重新启动？（y/n）"
        read -r terminate
        if [ "$terminate" = "y" ] || [ "$terminate" = "Y" ]; then
            screen -S cysic_verifier -X quit
            echo "已终止现有 screen 会话。"
        else
            echo "未终止现有会话。您可以通过 'screen -r cysic_verifier' 查看当前会话。"
            return 0
        fi
    fi

    cd ~/cysic-verifier/ || { echo "错误：无法切换到~/cysic-verifier/目录。请确保已安装节点。"; return 1; }
    screen -dmS cysic_verifier bash start.sh
    if [ $? -ne 0 ]; then
        echo "错误：启动验证程序失败。请检查start.sh脚本或等待几分钟后重试。"
        echo "如果看到'err: rpc error'，请等待几分钟，验证程序将尝试连接。"
    else
        echo "验证程序已在新的 screen 会话 'cysic_verifier' 中重新启动！"
        echo "您可以使用选项 2 查看 screen 日志，或运行 'screen -r cysic_verifier' 直接进入会话。"
    fi
}

# 主菜单
while true; do
    clear
    echo "=== Cysic 验证程序管理菜单 ==="
    echo "1. 安装并运行节点"
    echo "2. 查看 screen 日志"
    echo "3. 重新连接验证程序"
    echo "4. 退出脚本"
    echo "请输入您的选择（1-4）："
    read -r choice

    case $choice in
        1)
            install_and_run_node
            echo "按 Enter 键返回菜单..."
            read
            ;;
        2)
            view_logs
            echo "按 Enter 键返回菜单..."
            read
            ;;
        3)
            reconnect_verifier
            echo "按 Enter 键返回菜单..."
            read
            ;;
        4)
            echo "退出脚本..."
            exit 0
            ;;
        *)
            echo "无效的选择，请输入 1-4。"
            echo "按 Enter 键继续..."
            read
            ;;
    esac
done
