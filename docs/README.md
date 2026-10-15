# 文档索引

- [`architecture.md`](./architecture.md)：当前有效的 NixOS / nix-darwin 架构、module seam 与装配约束。
- [`../README.md`](../README.md)：主机矩阵、安装指南、日常更新和排障命令。
- [`physical-install.md`](./physical-install.md)：7950X 核显、独立 SSD 双系统、Live 安装联网与 Mihomo 配置。
- `archive/`：已完成迁移的历史规格与实施计划，仅用于追溯决策；其中的分支名、路径和命令可能已过期，不代表当前配置。

判断当前行为时，以 `flake.nix`、`hosts/`、`modules/`、`home/` 和 `architecture.md` 为准。

完整验证使用：

```bash
scripts/check.sh
```

该入口先执行结构回归测试，再检查 Darwin inputs 是否已经进入 `flake.lock`，最后真实求值四个系统 host 和 generic Linux Home Manager 输出，并校验 physical 的核显、独立磁盘、代理消费者与其他 host 的隔离。结构和求值测试允许 UUID 占位；实际安装前必须按 physical 安装指南替换占位。
