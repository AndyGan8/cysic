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
    bash start.sh &
    if [ $? -ne 0 ]; then
        echo "错误：启动验证程序失败。请检查start.sh脚本或等待几分钟后重试。"
        echo "如果看到'err: rpc error'，请等待几分钟，验证程序将尝试连接。"
    else
        echo "验证程序已启动！请等待消息，如'start sync data from server'，表示成功运行。"
        echo "重要：您的助记词文件已生成，位于 ~/.cysic/keys/ 文件夹。"
        echo "请妥善备份此文件夹中的文件，否则您将无法再次运行验证程序。"
    fi
}

# 函数：查看日志
view_logs() {
    LOG_DIR=~/cysic-verifier/
    if [ -d "$LOG_DIR" ]; then
        echo "正在检查 ~/cysic-verifier/ 目录中的日志文件..."
        LOG_FILES=$(find "$LOG_DIR" -type f -name "*.log" 2>/dev/null)
        if [ -n "$LOG_FILES" ]; then
            echo "找到以下日志文件："
            echo "$LOG_FILES"
            echo "请输入要查看的日志文件路径（或按 Enter 跳过）："
            read -r LOG_FILE
            if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
                echo "显示日志文件：$LOG_FILE"
                cat "$LOG_FILE"
            else
                echo "未选择有效的日志文件或文件不存在。"
            fi
        else
            echo "未在 ~/cysic-verifier/ 目录中找到日志文件。"
        fi
    else
        echo "错误：未找到 ~/cysic-verifier/ 目录。请确保已完成节点安装。"
    fi
}

# 函数：重新连接验证程序
reconnect_verifier() {
    echo "正在尝试重新连接验证程序..."
    cd ~/cysic-verifier/ || { echo "错误：无法切换到~/cysic-verifier/目录。请确保已安装节点。"; return 1; }
    bash start.sh &
    if [ $? -ne 0 ]; then
        echo "错误：启动验证程序失败。请检查start.sh脚本或等待几分钟后重试。"
        echo "如果看到'err: rpc error'，请等待几分钟，验证程序将尝试连接。"
    else
        echo "验证程序已重新启动！请等待消息，如'start sync data from server'，表示成功运行。"
    fi
}

# 主菜单
while true; do
    clear
    echo "=== Cysic 验证程序管理菜单 ==="
    echo "1. 安装并运行节点"
    echo "2. 查看日志"
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
