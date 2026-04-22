# stress-ng 版本

这个文件说明 `stress-ng` 独立版本的使用方式。

## 文件

- `run-stress-ng.sh`
- `config.stress-ng.env`

## 安装依赖

```bash
sudo apt update
sudo apt install -y stress-ng lm-sensors
```

## 使用方法

```bash
cd tasks/server-stress-test
chmod +x run-stress-ng.sh
./run-stress-ng.sh
```

如果要自定义配置：

```bash
./run-stress-ng.sh /path/to/your-config.env
```

## 说明

- 这是独立的 `stress-ng` 方案，不会覆盖当前 `stressapptest` 方案
- 默认日志目录：`logs-stress-ng/`
- 默认状态目录：`state-stress-ng/`
- 默认报告目录：`report-stress-ng/`

## 适用场景

更适合：
- 长时间整机压力测试
- 强调可控、可观测、易调试
- 需要结合 CPU / 温度 / 内存区间做长期跑测
