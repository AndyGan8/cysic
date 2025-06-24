#!/bin/bash

# 一键脚本用于设置和运行Cysic验证程序，包含主菜单，使用 Docker 运行节点

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

    # 检查 Docker 是否安装
    if ! command -v docker &> /dev/null; then
        echo "错误：未检测到 Docker，请先安装 Docker。"
        echo "您可以运行以下命令安装 Docker（适用于 Ubuntu）："
        echo "sudo apt update && sudo apt install -y docker.io && sudo systemctl start docker && sudo systemctl enable docker"
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

    echo "等待安装完成，启动 Docker 容器..."
    sleep 10  # 等待安装完成，时间可根据需要调整
    cd ~/cysic-verifier/ || { echo "错误：无法切换到~/cysic-verifier/目录"; return 1; }

    # 检查是否已有 Docker 容器
    if docker ps -a --filter "name=cysic_verifier" | grep -q "cysic_verifier"; then
        echo "警告：已存在名为 'cysic_verifier' 的 Docker 容器。"
        echo "是否要停止并删除现有容器并重新启动？（y/n）"
        read -r terminate
        if [ "$terminate" = "y" ] || [ "$terminate" = "Y" ]; then
            docker stop cysic_verifier &> /dev/null
            docker rm cysic_verifier &> /dev/null
            echo "已停止并删除现有 Docker 容器。"
        else
            echo "未删除现有容器。您可以通过 'docker logs cysic_verifier' 查看容器日志。"
            return 0
        fi
    fi

    # 运行 Docker 容器
    # 假设 start.sh 需要在容器内执行，并挂载 ~/.cysic/keys 和 ~/cysic-verifier 目录
    docker run -d --name cysic_verifier \
        -v "$HOME/.cysic/keys:/root/.cysic/keys" \
        -v "$HOME/cysic-verifier:/app" \
        --workdir /app \
        --restart unless-stopped \
        cysic/verifier:latest bash start.sh
    if [ $? -ne 0 ]; then
        echo "错误：启动 Docker 容器失败。请检查 Docker 环境或 start.sh 脚本。"
        echo "如果看到'err: rpc error'，请等待几分钟，验证程序将尝试连接。"
    else
        echo "验证程序已在 Docker 容器 'cysic_verifier' 中启动！"
        echo "您可以通过选项 2 或运行 'docker logs cysic_verifier' 查看实时日志。"
        echo "重要：您的助记词文件已生成，位于 ~/.cysic/keys/ 文件夹。"
        echo "请妥善备份此文件夹中的文件，否则您将无法再次运行验证程序。"
    fi
}

# 函数：查看 Docker 容器日志
view_logs() {
    # 检查 Docker 容器是否存在
    if docker ps -a --filter "name=cysic_verifier" | grep -q "cysic_verifier"; then
        echo "找到 Docker 容器 'cysic_verifier'。"
        echo "您可以查看实时日志，命令为：docker logs -f cysic_verifier"
        echo "是否要查看实时日志？（y/n）"
        read -r view_docker_logs
        if [ "$view_docker_logs" = "y" ] || [ "$view_docker_logs" = "Y" ]; then
            docker logs -f cysic_verifier
        else
            echo "您选择了不查看日志。可以通过 'docker logs -f cysic_verifier' 随时查看。"
        fi
    else
        echo "错误：未找到 Docker 容器 'cysic_verifier'。"
        echo "请确保已通过选项 1 启动验证程序，或检查容器是否已被删除。"
        echo "您可以运行 'docker ps -a' 查看所有容器。"
    fi
}

# 函数：重新连接验证程序（核心逻辑）
reconnect_verifier_core() {
    cd ~/cysic-verifier/ || { echo "错误：无法切换到~/cysic-verifier/目录。请确保已安装节点。"; return 1; }
    # 停止并删除现有容器
    if docker ps -a --filter "name=cysic_verifier" | grep -q "cysic_verifier"; then
        docker stop cysic_verifier &> /dev/null
        docker rm cysic_verifier &> /dev/null
    fi
    # 重新运行容器
    docker run -d --name cysic_verifier \
        -v "$HOME/.cysic/keys:/root/.cysic/keys" \
        -v "$HOME/cysic-verifier:/app" \
        --workdir /app \
        --restart unless-stopped \
        cysic/verifier:latest bash start.sh
    if [ $? -ne 0 ]; then
        echo "错误：启动 Docker 容器失败。请检查 Docker 环境或 start.sh 脚本。"
        echo "如果看到'err: rpc error'，请等待几分钟，验证程序将尝试连接。"
        return 1
    else
        echo "验证程序已在新的 Docker 容器 'cysic_verifier' 中重新启动！"
        return 0
    fi
}

# 函数：手动或自动重新连接验证程序
reconnect_verifier() {
    echo "=== 重新连接验证程序子菜单 ==="
    echo "1. 手动重新连接验证程序"
    echo "2. 启用每小时自动重新连接"
    echo "3. 禁用自动重新连接"
    echo "4. 返回主菜单"
    echo "请输入您的选择（1-4）："
    read -r sub_choice

    case $sub_choice in
        1)
            echo "正在尝试手动重新连接验证程序..."
            reconnect_verifier_core
            echo "按 Enter 键返回子菜单..."
            read
            ;;
        2)
            echo "启用每小时自动重新连接验证程序..."
            # 检查是否已存在自动重新连接进程
            if [ -f /tmp/cysic_auto_reconnect.pid ]; then
                pid=$(cat /tmp/cysic_auto_reconnect.pid)
                if ps -p "$pid" > /dev/null; then
                    echo "自动重新连接已启用（PID: $pid）。无需重复启用。"
                else
                    rm /tmp/cysic_auto_reconnect.pid
                fi
            fi
            # 启动后台循环
            (
                while true; do
                    if docker ps -a --filter "name=cysic_verifier" | grep -q "cysic_verifier"; then
                        docker stop cysic_verifier &> /dev/null
                        docker rm cysic_verifier &> /dev/null
                        echo "[$(date)] 自动停止并删除现有 Docker 容器。" >> ~/cysic_auto_reconnect.log
                    fi
                    reconnect_verifier_core && echo "[$(date)] 自动重新连接成功。" >> ~/cysic_auto_reconnect.log || echo "[$(date)] 自动重新连接失败。" >> ~/cysic_auto_reconnect.log
                    sleep 3600  # 每小时（3600秒）执行一次
                done
            ) &
            pid=$!
            echo "$pid" > /tmp/cysic_auto_reconnect.pid
            echo "自动重新连接已启用（PID: $pid）。日志记录在 ~/cysic_auto_reconnect.log。"
            echo "按 Enter 键返回子菜单..."
            read
            ;;
        3)
            echo "禁用自动重新连接..."
            if [ -f /tmp/cysic_auto_reconnect.pid ]; then
                pid=$(cat /tmp/cysic_auto_reconnect.pid)
                if ps -p "$pid" > /dev/null; then
                    kill "$pid"
                    rm /tmp/cysic_auto_reconnect.pid
                    echo "自动重新连接已禁用。"
                else
                    rm /tmp/cysic_auto_reconnect.pid
                    echo "未找到运行中的自动重新连接进程，但已清理 PID 文件。"
                fi
            else
                echo "未找到自动重新连接进程，无需禁用。"
            fi
            echo "按 Enter 键返回子菜单..."
            read
            ;;
        4)
            return 0
            ;;
        *)
            echo "无效的选择，请输入 1-4。"
            echo "按 Enter 键继续..."
            read
            ;;
    esac
}

# 函数：删除容器和节点（保留 ~/.cysic/keys/ 文件夹）
delete_session_and_node() {
    echo "警告：此操作将停止并删除 'cysic_verifier' Docker 容器并删除 ~/cysic-verifier/ 目录。"
    echo "注意：~/.cysic/keys/ 文件夹（包含助记词）将被保留。"
    echo "如果启用了自动重新连接，也将被禁用。"
    echo "是否继续？（y/n）"
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        # 禁用自动重新连接
        if [ -f /tmp/cysic_auto_reconnect.pid ]; then
            pid=$(cat /tmp/cysic_auto_reconnect.pid)
            if ps -p "$pid" > /dev/null; then
                kill "$pid"
                rm /tmp/cysic_auto_reconnect.pid
                echo "已禁用自动重新连接。"
            else
                rm /tmp/cysic_auto_reconnect.pid
                echo "未找到运行中的自动重新连接进程，但已清理 PID 文件。"
            fi
        fi

        # 检查并删除 Docker 容器
        if docker ps -a --filter "name=cysic_verifier" | grep -q "cysic_verifier"; then
            docker stop cysic_verifier &> /dev/null
            docker rm cysic_verifier &> /dev/null
            echo "已停止并删除 'cysic_verifier' Docker 容器。"
        else
            echo "未找到 'cysic_verifier' Docker 容器，跳过删除步骤。"
        fi

        # 删除 ~/cysic-verifier/ 目录
        if [ -d ~/cysic-verifier/ ]; then
            rm -rf ~/cysic-verifier/
            if [ $? -eq 0 ]; then
                echo "已成功删除 ~/cysic-verifier/ 目录。"
            else
                echo "错误：删除 ~/cysic-verifier/ 目录失败，请检查权限或目录状态。"
                return 1
            fi
        else
            echo "未找到 ~/cysic-verifier/ 目录，跳过删除步骤。"
        fi

        # 确认 ~/.cysic/keys/ 文件夹保留
        if [ -d ~/.cysic/keys/ ]; then
            echo "已保留 ~/.cysic/keys/ 文件夹，请确保已备份其中的助记词文件。"
        else
            echo "警告：未找到 ~/.cysic/keys/ 文件夹，可能尚未生成助记词。"
        fi
    else
        echo "操作已取消，未删除任何内容。"
    fi
}

# 主菜单
while true; do
    clear
    echo "=== 脚本由Andy甘免费开源，推特@mingfei2022 ==="
    echo "=== Cysic 验证程序管理菜单（使用 Docker） ==="
    echo "1. 安装并运行节点"
    echo "2. 查看 Docker 容器日志"
    echo "3. 重新连接验证程序（手动/自动每小时）"
    echo "4. 删除容器和节点（保留 keys 文件夹）"
    echo "5. 退出脚本"
    echo "请输入您的选择（1-5）："
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
            ;;
        4)
            delete_session_and_node
            echo "按 Enter 键返回菜单..."
            read
            ;;
        5)
            echo "退出脚本..."
            exit 0
            ;;
        *)
            echo "无效的选择，请输入 1-5。"
            echo "按 Enter 键继续..."
            read
            ;;
    esac
done
