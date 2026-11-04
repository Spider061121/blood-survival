#!/usr/bin/env bash
# 血战到底 · Linux 一键部署脚本
#
# 适用：已安装 Node.js >= 24 的 Linux 服务器（宝塔用户也可在 SSH 终端里执行）
# 用法：bash deploy.sh
#
# 做的事：
#   1. 校验 Node 版本
#   2. 安装后端依赖
#   3. 用 pm2 启动服务（没有 pm2 就尝试全局安装）
#   4. 提示后续反代配置

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

PORT="${PORT:-3000}"
HOST="${HOST:-127.0.0.1}"

echo "==> 检查 Node.js 版本"
NODE_VER="$(node -v 2>/dev/null || true)"
if [[ -z "$NODE_VER" ]]; then
  echo "错误：未找到 node。请先安装 Node.js 24+：https://nodejs.org/zh-cn/download"
  exit 1
fi
MAJOR="$(echo "$NODE_VER" | sed 's/^v//' | cut -d. -f1)"
if [[ "$MAJOR" -lt 24 ]]; then
  echo "错误：当前 Node 版本 $NODE_VER 过低，本项目需要 Node >= 24（内置 node:sqlite）"
  exit 1
fi
echo "    Node 版本：$NODE_VER"

echo "==> 安装后端依赖"
cd "$ROOT/server"
npm install --omit=dev --no-audit --no-fund

echo "==> 准备运行环境变量"
export PORT HOST TRUST_PROXY="${TRUST_PROXY:-1}"
# 会话签名密钥未设置时，服务会自动生成并保存到 server/data/.session-secret

echo "==> 检查 pm2"
if ! command -v pm2 >/dev/null 2>&1; then
  echo "    未找到 pm2，尝试全局安装..."
  npm install -g pm2 || { echo "pm2 安装失败，请手动执行：npm install -g pm2"; exit 1; }
fi

echo "==> 启动服务（pm2）"
cd "$ROOT"
pm2 start server/index.js --name blood-survival --update-env
pm2 save

echo
echo "✅ 部署完成！"
echo "   服务监听：http://${HOST}:${PORT}"
echo
echo "后续步骤："
echo "   1. 在宝塔/Nginx 里把域名反代到 http://127.0.0.1:${PORT}"
echo "      宝塔：网站 → 设置 → 反向代理 → 目标 URL 填 http://127.0.0.1:${PORT}"
echo "   2. 如需开机自启：执行 pm2 startup，按提示复制执行显示的命令"
echo "   3. 常用命令：pm2 status / pm2 logs blood-survival / pm2 restart blood-survival"
