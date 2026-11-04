# 血战到底 · 无尽生存小游戏

打怪刷血的无限模式小游戏：**没有输赢，只有血量**。击杀怪物回血、被撞掉血，血量归零这一局就结束——比谁活得更久。

- **账号登录**：注册/登录后游戏，成绩自动绑定账号
- **排行榜按个人最好成绩排名**：每人一条，存活时间优先、击杀次之
- 伤害随时间增长：`10 + 每 15 秒 +3`，封顶 45，活得越久越紧张
- **激烈电子风音频**：Web Audio 实时合成 BGM（失真贝斯 + 四四拍鼓点，随存活时间加速）+ 全套音效，右上角 🔊 可静音，无任何音频文件
- 纯前端 Canvas 渲染 + Node.js 后端，可部署在阿里云 ECS / 宝塔面板

## 目录结构

```
小游戏/
├── server/                    # 后端：Express 静态托管 + 账号/排行榜 API
│   ├── index.js               # 服务入口（会话密钥自动生成）
│   ├── app.js                 # 路由、会话、参数校验、限频
│   ├── db.js                  # node:sqlite 封装（零原生依赖，旧库自动迁移）
│   ├── test/api.test.js       # 接口测试
│   └── data/game.db           # 运行后自动生成（SQLite）
├── web/                       # 前端游戏（无构建步骤）
│   ├── index.html
│   ├── css/style.css
│   └── js/game.js, js/api.js, js/audio.js
├── tools/sim-game.js          # 游戏逻辑冒烟测试
├── deploy/                    # ecosystem.config.js / systemd / nginx 示例
├── deploy.sh                  # Linux 一键部署脚本（pm2）
├── 宝塔面板部署图文教程.md     # 宝塔面板逐步部署指南
└── docs/                      # 设计规格
```

## 本地运行

需要 Node.js ≥ 24（用到内置 `node:sqlite`）。

```bash
cd server
npm install
npm start
```

打开 http://127.0.0.1:3000 ，注册一个账号即可开玩。默认只监听 `127.0.0.1`，局域网/公网访问请设置 `HOST=0.0.0.0`。

## 账号与排行榜规则

- 用户名 3~16 位（中文/字母/数字/下划线），密码 6~64 位，密码经 `scrypt` 加盐哈希存储。
- 登录后会话保持 7 天（HttpOnly Cookie），点右上角「退出」清除。
- 每局结束**自动提交**，绑定当前账号；排行榜每人只显示**个人最好成绩**（存活时间优先，击杀次之）。
- 登录/注册限频（单 IP 每分钟 10 次），成绩提交限频（单 IP 每分钟 5 次）。

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `PORT` | `3000` | 监听端口 |
| `HOST` | `127.0.0.1` | 监听地址；直接对外暴露时改 `0.0.0.0` |
| `DB_FILE` | `server/data/game.db` | SQLite 文件路径 |
| `TRUST_PROXY` | 空 | 在 Nginx/宝塔反代后设为 `1`，才能拿到真实客户端 IP 做限频 |
| `SESSION_SECRET` | 自动生成 | 会话签名密钥；不填会自动生成并保存到 `server/data/.session-secret` |
| `RATE_MAX` | `5` | 单 IP 每分钟最多提交成绩次数 |
| `AUTH_RATE_MAX` | `10` | 单 IP 每分钟最多注册/登录次数 |

## 接口

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/register` | 注册 `{username, password}`，成功后自动登录（下发会话 Cookie） |
| POST | `/api/login` | 登录 `{username, password}` |
| POST | `/api/logout` | 退出登录（清除会话 Cookie） |
| GET | `/api/me` | 当前用户、个人最好成绩与排名（需登录） |
| POST | `/api/score` | 提交成绩 `{survivalSeconds, kills, endHp}`，自动绑定登录账号 |
| GET | `/api/leaderboard?limit=50` | 排行榜，每人一条个人最好成绩（limit 最大 100） |
| GET | `/api/health` | 健康检查 |

提交成绩校验：存活时间 0~86400 秒、击杀数整数、结束血量 0~100。

## 测试

```bash
cd server
npm test                 # 接口测试（14 项：注册/登录/会话/限频/按人最好成绩排名/旧库迁移等）
cd ..
node tools/sim-game.js   # 游戏逻辑冒烟测试（登录态/刷怪/开火/击杀/掉血/自动提交/结算/重开）
```

> 说明：`node --test` 在个别受限环境（如 Windows 沙箱）会因进程派发被拒而失败，
> 此时可用 `node test/api.test.js` 直接在本进程内执行测试。

## 部署到阿里云（宝塔面板）

见 [宝塔面板部署图文教程.md](./宝塔面板部署图文教程.md)，核心步骤：

1. 上传项目到 `/www/wwwroot/blood-survival`
2. 宝塔安装 Node.js 24，`cd server && npm install --omit=dev`
3. 宝塔「Node 项目」添加：启动文件 `server/index.js`、端口 3000、开机自启
4. 新建站点并反向代理到 `http://127.0.0.1:3000`
5. 安全组放行 80/443

**从旧版本升级**：覆盖上传 `web/` 和 `server/`（别覆盖 `server/data/`）→ 重启 Node 项目。数据库会自动迁移，旧成绩备份在 `scores_v1_backup` 表。

纯命令行服务器可以用 `bash deploy.sh`（pm2 方式）。

## 备份

数据都在 `server/data/` 一个目录：`game.db`（账号 + 成绩）、`.session-secret`（会话密钥）。定期拷贝整个 `server/data/` 目录即可。
