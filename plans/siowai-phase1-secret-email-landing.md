# SiowAI 第一阶段落地方案

## 当前主机现状（2026-04-18）

- `jq` 已可用
- `bw`（Bitwarden CLI）当前未安装
- 说明：长期方案可落地，但还差 Bitwarden CLI 或等价读取通道

## 第一阶段目标

先只落地一个闭环：

**写邮件 -> 你确认 -> 读取 secret -> 发出 -> 返回结果**

不在第一阶段做：

- 全量密码接管
- 多邮箱并发管理
- 交换机配置变更
- 高风险服务器自动变更

## 推荐的 Bitwarden 组织方式

建议先建一个独立的文件夹或分类：

- `SiowAI`

在里面先只建这一条：

- `mail/freyrtech/primary-smtp`

后续扩展时按同一规范命名：

- `server/prod/app-01/ssh`
- `server/prod/db-01/ssh`
- `network/core-switch/admin`
- `api/openai/main`
- `api/alicloud/ops`

## 第一条邮箱 secret 建议字段

条目名：

- `mail/freyrtech/primary-smtp`

建议字段：

1. `display_name`
   - 发件显示名
   - 例：`Siow Xu`

2. `email_address`
   - 发件邮箱地址
   - 例：`<your-email@domain>`

3. `smtp_host`
   - SMTP 服务器地址
   - 例：`smtp.example.com`

4. `smtp_port`
   - SMTP 端口
   - 例：`465` 或 `587`

5. `smtp_username`
   - 通常与邮箱地址相同

6. `smtp_secret`
   - SMTP 授权码 / 应用专用密码
   - 不要填主密码

7. `security_mode`
   - `ssl` / `starttls`

8. `purpose`
   - 例：`SiowAI outgoing mail only`

9. `rotation_note`
   - 例：`rotate if exposed in chat or logs`

## 邮件工作流定义

### 阶段 A，起草

你告诉 SiowAI：

- 收件人
- 主题（可选）
- 目的
- 语气
- 语言

SiowAI 输出：

- 邮件主题
- 邮件正文
- 必要时的风险提示

### 阶段 B，确认

只有当你明确说出类似以下指令时，才允许进入发送阶段：

- `确认发送`
- `可以发了`
- `按这个发`

如果缺少关键字段，SiowAI 先补问，不发送。

关键字段包括：

- 收件人
- 主题
- 正文
- 发件身份

### 阶段 C，读取 secret

发送前，SiowAI 只读取：

- `mail/freyrtech/primary-smtp`

不读取其他账号，不回显 secret 本身。

### 阶段 D，执行发送

发送后只回：

- 发送是否成功
- 目标收件人
- 主题
- 时间
- 失败原因（如有）

不回显：

- 授权码
- SMTP 密码
- 完整底层认证串

## 发送审批边界

### 默认允许

- 起草邮件
- 润色邮件
- 翻译邮件
- 生成回复建议

### 必须确认

- 真正发送邮件
- 新增发件身份
- 修改已存在的 secret 绑定关系
- 添加附件后发送

## 建议的确认口令

为了以后稳定，建议把发信确认收敛成固定短语：

- `确认发送`

这会比“嗯”“可以”“发吧”更稳，减少误发。

## 第一阶段需要补齐的东西

1. 安装 `bw`（Bitwarden CLI）
2. 登录 Bitwarden
3. 解锁 vault
4. 创建 `mail/freyrtech/primary-smtp`
5. 写一个本地读取脚本，只返回需要字段
6. 再接入实际发信脚本

## 推荐的读取原则

本地读取逻辑应做到：

1. 只按条目名读取
2. 只提取需要字段
3. 不把完整 secret 打进日志
4. 不把 secret 回传到聊天

## 现实建议

目前最合理的推进顺序是：

1. 先由你在 Bitwarden 建好第一条邮箱 secret
2. 我这边再接 `bw` CLI
3. 先做“读 secret 不发信”的测试
4. 再做正式邮件发送测试

## 下一步动作

如果继续推进，下一步最实际的是：

1. 安装 Bitwarden CLI
2. 定第一条 secret 的最终字段值
3. 写读取脚本
4. 写发信脚本
