#!/bin/bash
set -e

INSTALL_DIR="/opt/cli-proxy-api"
SERVICE_NAME="cli-proxy-api"
BINARY_NAME="CLIProxyAPI"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORCE_CONFIG=false

# 解析参数
for arg in "$@"; do
  case $arg in
    --force-config)
      FORCE_CONFIG=true
      ;;
  esac
done

echo "=== CLIProxyAPI 部署脚本 ==="
echo ""

# 检查 root
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 用户运行: sudo bash install.sh"
  exit 1
fi

# 检查二进制文件
if [ ! -f "$SCRIPT_DIR/$BINARY_NAME" ]; then
  echo "错误: 未找到 $BINARY_NAME 二进制文件"
  exit 1
fi

# 停止旧服务（如果存在）
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
  echo "[0/6] 停止旧服务..."
  systemctl stop "$SERVICE_NAME"
fi

# 清理旧文件（保留 config.yaml 和 auths 目录）
echo "[1/7] 清理旧安装..."
if [ -d "$INSTALL_DIR" ]; then
  # 备份配置文件
  if [ -f "$INSTALL_DIR/config.yaml" ]; then
    cp "$INSTALL_DIR/config.yaml" "/tmp/cli-proxy-api-config.yaml.bak"
    echo "  已备份 config.yaml 到 /tmp/cli-proxy-api-config.yaml.bak"
  fi
  # 备份 auths 目录
  if [ -d "$INSTALL_DIR/auths" ] && [ "$(ls -A "$INSTALL_DIR/auths" 2>/dev/null)" ]; then
    cp -r "$INSTALL_DIR/auths" "/tmp/cli-proxy-api-auths.bak"
    echo "  已备份 auths 目录到 /tmp/cli-proxy-api-auths.bak/"
  fi
  # 删除旧安装
  rm -rf "$INSTALL_DIR"
  echo "  旧安装已清除"
fi

# 创建目录
echo "[2/7] 创建目录..."
mkdir -p "$INSTALL_DIR"/{auths,logs,static}

# 恢复备份
if [ -f "/tmp/cli-proxy-api-config.yaml.bak" ]; then
  cp "/tmp/cli-proxy-api-config.yaml.bak" "$INSTALL_DIR/config.yaml"
  echo "  已恢复 config.yaml"
fi
if [ -d "/tmp/cli-proxy-api-auths.bak" ]; then
  cp -r /tmp/cli-proxy-api-auths.bak/* "$INSTALL_DIR/auths/" 2>/dev/null || true
  echo "  已恢复 auths 目录"
fi

# 复制二进制
echo "[3/7] 部署二进制文件..."
cp "$SCRIPT_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

# 复制管理面板
if [ -f "$SCRIPT_DIR/static/management.html" ]; then
  cp "$SCRIPT_DIR/static/management.html" "$INSTALL_DIR/static/management.html"
  echo "  管理面板已部署到 $INSTALL_DIR/static/management.html"
else
  echo "  警告: 未找到 static/management.html，管理面板将不可用"
fi

# 配置文件
echo "[4/7] 处理配置文件..."
if [ "$FORCE_CONFIG" = true ] || [ ! -f "$INSTALL_DIR/config.yaml" ]; then
  cp "$SCRIPT_DIR/config.example.yaml" "$INSTALL_DIR/config.yaml"
  if [ "$FORCE_CONFIG" = true ]; then
    echo "  已强制覆盖 config.yaml（旧配置备份在 /tmp/cli-proxy-api-config.yaml.bak）"
  else
    echo "  已生成 config.yaml，请编辑配置后重启服务"
  fi
else
  echo "  config.yaml 已存在，跳过覆盖（使用 --force-config 强制覆盖）"
  echo "  新版示例配置: $SCRIPT_DIR/config.example.yaml"
fi

# 创建 systemd 服务
echo "[5/7] 配置 systemd 服务..."
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=CLIProxyAPI Service
After=network.target

[Service]
Type=simple
User=root
Environment=HOME=/root
Environment=MANAGEMENT_STATIC_PATH=$INSTALL_DIR/static
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$BINARY_NAME
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
echo "[6/7] 启动服务..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# 检查状态
echo "[7/7] 检查状态..."
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo ""
  echo "=== 部署成功 ==="
  echo "  服务状态: 运行中"
  echo "  监听端口: 8317 (默认)"
  echo "  配置文件: $INSTALL_DIR/config.yaml"
  echo "  管理面板: $INSTALL_DIR/static/management.html"
  echo "  认证目录: $INSTALL_DIR/auths"
  echo "  日志目录: $INSTALL_DIR/logs"
  echo ""
  echo "常用命令:"
  echo "  编辑配置: nano $INSTALL_DIR/config.yaml"
  echo "  重启服务: systemctl restart $SERVICE_NAME"
  echo "  查看日志: journalctl -u $SERVICE_NAME -f"
  echo "  停止服务: systemctl stop $SERVICE_NAME"
  echo "  查看状态: systemctl status $SERVICE_NAME"
  echo ""
  echo "更新管理面板:"
  echo "  替换 $INSTALL_DIR/static/management.html 后刷新浏览器即可"
else
  echo ""
  echo "=== 服务启动失败 ==="
  echo "查看日志: journalctl -u $SERVICE_NAME --no-pager -n 30"
  exit 1
fi
