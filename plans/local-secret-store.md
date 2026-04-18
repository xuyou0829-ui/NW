# SiowAI 本机 Secret Store 方案

## 结论

把账号密码直接存放在 SiowAI 所在主机上，**技术上可行**，而且在“暂时不接 Bitwarden 自动读取”的阶段，是一个现实可用的过渡方案。

但它不是最理想的长期方案。

### 风险判断

它的安全性大致是：

- **比聊天里发密码安全很多**
- **比明文散落在文件里安全很多**
- **不如专业密钥库 / Secrets Manager 稳**

## 适用场景

适合：

- 你现在不方便操作终端完成 Bitwarden CLI 登录
- 你希望 SiowAI 能先开始做事
- 你愿意先用“本机受控存储”作为过渡

不适合：

- 需要多人协作审计
- 需要跨多台机器分发 secret
- 需要严格合规或长期托管大量高价值凭证

## 推荐原则

1. 不存主密码，只存最小权限凭证
2. 一项用途一条 secret
3. 每个 secret 单独文件，不做大杂烩总表
4. secret 与用途说明分离
5. 文件权限收紧到最小
6. 不通过聊天传输长期有效 secret

## 推荐目录结构

建议放在工作区外或单独受限目录，例如：

- `~/.openclaw/secrets/`

目录下按用途分层：

- `~/.openclaw/secrets/mail/freyrtech/primary-smtp.json`
- `~/.openclaw/secrets/server/app-01/login.json`
- `~/.openclaw/secrets/network/core-switch-01/login.json`
- `~/.openclaw/secrets/network/core-switch-01/enable.json`
- `~/.openclaw/secrets/api/alicloud/ops.json`

## 权限建议

### 目录权限

- secrets 根目录：`700`

### 文件权限

- 每个 secret 文件：`600`

### 访问原则

- 仅 OpenClaw 运行用户可读
- 不给其他普通用户读权限
- 不放进 git
- 不放进 workspace 可见文档里

## 文件内容模板

每个 secret 文件建议只保留执行所需字段。

例如 SMTP：

```json
{
  "kind": "mail_smtp",
  "username": "<your-email@domain>",
  "secret_value": "<smtp-app-password>",
  "endpoint_host": "smtp.example.com",
  "endpoint_port": 465,
  "auth_mode": "app_password",
  "security_mode": "ssl",
  "scope": "outgoing-mail-only"
}
```

例如服务器登录：

```json
{
  "kind": "server_ssh",
  "username": "ops",
  "secret_value": "<password-or-private-key>",
  "endpoint_host": "10.0.0.21",
  "endpoint_port": 22,
  "auth_mode": "password",
  "scope": "ssh-login"
}
```

## 不建议放进去的内容

1. Bitwarden 主密码
2. 邮箱主密码（优先用授权码）
3. 多个系统共用的万能管理员密码
4. 不必要的个人敏感资料

## 执行时的读取规则

SiowAI 读取 secret 时应遵守：

1. 只按明确路径读取
2. 不遍历整个 secrets 目录做“扫库”
3. 只提取必要字段
4. 不把 secret_value 输出到聊天
5. 不把完整文件打进日志

## 审批边界建议

### 可默认允许

- 读取用于只读检查的 secret
- 读取用于起草或配置验证的非发信 secret

### 必须确认

- 读取会触发外发动作的 secret
- 读取高权限管理员 secret
- 使用新接入的敏感凭证
- 执行真正会产生副作用的动作

## 长期建议

本机 Secret Store 适合作为**过渡层**。

长期推荐路径仍然是：

1. 先用本机受控 secret 文件把流程跑起来
2. 等条件合适，再迁移到 Bitwarden 自动读取或专门 Secrets Manager
3. 敏感度最高的凭证优先迁移

## 对 SiowXu 当前最合适的建议

当前最现实的方案是：

1. 继续用 Bitwarden 做你自己的密码总库
2. 只把“需要让 SiowAI 执行”的那几条凭证，复制到本机 Secret Store
3. 这些凭证只用最小权限版本（SMTP 授权码、API token、设备登录凭证）
4. 不把主密码交给 SiowAI

## 总结

“密码账号存你这里是否可行？”

答案是：**可行，但应限定为本机受控 secret store，不应等同于把所有核心密码长期交给聊天助手。**

如果要这样做，必须同时做到：

- 最小权限
- 单项分拆
- 路径明确
- 权限收紧
- 不进聊天
- 可轮换可撤销
