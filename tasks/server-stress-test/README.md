# 服务器压力测试方案总览

这里拆成两个平行目录，分别对应两种定位不同的方案。

## 目录结构

- `stressapptest/`
- `stress-ng/`

## 定位

### `stressapptest/`
更偏硬件侧、内存接口侧的压力测试。

适合：
- 验证新内存条整体稳定性
- 更关注内存子系统、控制器、总线、高流量搬运
- 想做偏“硬件验收”风格的长时间测试

入口：
```bash
cd tasks/server-stress-test/stressapptest
./run.sh
```

说明文档：
- `tasks/server-stress-test/stressapptest/README.md`

### `stress-ng/`
更偏整机侧、可控性和可观测性更强的长期压力测试。

适合：
- 长时间整机 soak test
- 更强调 CPU / 温度 / 内存区间 / 进度展示
- 更容易按你的测试节奏做分段控制和调试

入口：
```bash
cd tasks/server-stress-test/stress-ng
./run.sh
```

说明文档：
- `tasks/server-stress-test/stress-ng/README.md`

## 我的建议

- 如果你要“验内存条合不合格”，优先看 `stressapptest/`
- 如果你要“做一个可控、可观测、方便调试的长期整机压力测试”，优先看 `stress-ng/`

如果以后要双保险，也可以：
- 先跑 `stressapptest/`
- 再补一轮 `stress-ng/`
