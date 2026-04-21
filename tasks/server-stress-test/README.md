# 服务器压力测试

这个目录用于存放服务器内存压力测试相关的脚本、配置、日志和报告。

当前实现为 Ubuntu / Linux 上的 Bash 方案，围绕 `stress-ng` 做多阶段内存压力测试。

## 目录说明

- `config.env`：测试配置
- `run.sh`：主控脚本
- `logs/`：运行时日志
- `state/`：当前状态文件
- `report/`：最终报告

## 默认测试策略

- 3 段 burn phase，每段 20 小时
- burn phase 内部按 1 小时切 chunk
- 每段 burn 之间休息 4 小时
- 内存压力默认 80%
- 终端实时显示：
  - 总进度
  - 当前阶段
  - 当前 chunk
  - CPU 利用率
  - 内存利用率
  - 温度
  - EDAC CE / UE 计数（如果系统支持）

## 依赖

建议先安装：

```bash
sudo apt update
sudo apt install -y stress-ng lm-sensors
```

`sensors` 读不到也能跑，只是最终报告会标记为 warning。

## 使用方法

```bash
cd tasks/server-stress-test
chmod +x run.sh
./run.sh
```

如果想用自定义配置文件：

```bash
./run.sh /path/to/your-config.env
```

## 配置项

关键配置在 `config.env`：

- `BURN_HOURS=20`
- `REST_HOURS=4`
- `BURN_PHASES=3`
- `CHUNK_HOURS=1`
- `MEMORY_PERCENT=80`
- `VM_WORKERS=1`
- `VM_METHOD=all`
- `CPU_WORKERS=0`
- `SAMPLE_SECONDS=5`
- `MAX_TEMP_C=90`
- `TIME_UNIT_SECONDS=3600`（默认别改，仅用于开发时缩短测试时间）

约束：

- `MEMORY_PERCENT` 最高限制为 80
- `BURN_HOURS` 必须能被 `CHUNK_HOURS` 整除

## 输出结果

运行结束后主要看：

- `logs/events.log`
- `logs/metrics.csv`
- `logs/stress-ng.log`
- `report/summary.txt`

## 判定逻辑

- `stress-ng` 异常退出：FAIL
- 温度超阈值：FAIL
- 新增 EDAC UE 错误：FAIL
- 新增 EDAC CE 错误：PASS WITH WARNING
- 温度不可读：PASS WITH WARNING
- 全部阶段完成且无异常：PASS
