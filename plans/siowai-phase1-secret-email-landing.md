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

### 条目类型建议

给 SiowAI 使用的自动化凭证，建议**统一用 Bitwarden 的 Secure Note**，不要混着用 Login、Card、Identity。

原因：

1. 我们要的是**结构化读取**，不是浏览器自动填表
2. 不同类型混用，后面字段会越来越乱
3. Secure Note 更适合统一命名、统一字段、统一脚本读取

在里面先只建这一条：

- `mail/freyrtech/primary-smtp`

后续扩展时按同一规范命名：

- `server/prod/app-01/ssh`
- `server/prod/db-01/ssh`
- `network/core-switch/admin`
- `api/openai/main`
- `api/alicloud/ops`

## 通用 secret 结构模板

我建议以后所有给 SiowAI 用的 secret，都尽量遵守同一套结构。

### 统一命名规则

格式建议：

- `<domain>/<system>/<account>/<purpose>`

例子：

- `mail/freyrtech/primary-smtp`
- `server/prod/app-01/ssh`
- `network/core-switch/admin`
- `api/alicloud/ops`

### 通用字段骨架

每条 Secure Note 建议至少有这些字段：

1. `path`
   - 条目唯一标识
   - 例：`mail/freyrtech/primary-smtp`

2. `kind`
   - secret 类型
   - 例：`mail_smtp` / `server_ssh` / `network_device` / `api_token`

3. `environment`
   - 例：`prod` / `test` / `home` / `lab`

4. `owner`
   - 这条 secret 属于哪个系统或业务

5. `endpoint_host`
   - 目标主机、服务地址或 API 域名

6. `endpoint_port`
   - 端口，没有可留空

7. `username`
   - 登录用户名、邮箱地址、账号名

8. `auth_mode`
   - 例：`password` / `app_password` / `token` / `ssh_key` / `ssl` / `starttls`

9. `secret_value`
   - 真正的秘密内容
   - 只在执行时读取

10. `scope`
   - 权限范围说明
   - 例：`outgoing-mail-only`

11. `approval_level`
   - 使用前需要的确认等级
   - 例：`read_only` / `send` / `change` / `admin`

12. `rotation_rule`
   - 什么时候轮换
   - 例：`rotate if exposed in chat or every 90d`

13. `revocation_hint`
   - 出问题时去哪里撤销

14. `notes`
   - 非敏感补充说明

## 第一条邮箱 secret 建议字段

条目名：

- `mail/freyrtech/primary-smtp`

建议字段：

1. `path`
   - `mail/freyrtech/primary-smtp`

2. `kind`
   - `mail_smtp`

3. `environment`
   - `prod`

4. `display_name`
   - 发件显示名
   - 例：`Siow Xu`

5. `email_address`
   - 发件邮箱地址
   - 例：`<your-email@domain>`

6. `endpoint_host`
   - SMTP 服务器地址
   - 例：`smtp.example.com`

7. `endpoint_port`
   - 例：`465` 或 `587`

8. `username`
   - 通常与邮箱地址相同

9. `auth_mode`
   - `app_password`

10. `secret_value`
   - SMTP 授权码 / 应用专用密码
   - 不要填主密码

11. `security_mode`
   - `ssl` / `starttls`

12. `scope`
   - `outgoing-mail-only`

13. `approval_level`
   - `send`

14. `rotation_rule`
   - `rotate if exposed in chat or logs`

15. `revocation_hint`
   - 记录去哪里撤销该授权码

16. `notes`
   - 非敏感备注

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
