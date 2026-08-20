# 文档索引

- [`architecture.md`](./architecture.md)：当前有效的 NixOS / nix-darwin 架构、module seam 与装配约束。
- [`../README.md`](../README.md)：主机矩阵、安装指南、日常更新和排障命令。
- `archive/`：已完成迁移的历史规格与实施计划，仅用于追溯决策；其中的分支名、路径和命令可能已过期，不代表当前配置。

判断当前行为时，以 `flake.nix`、`hosts/`、`modules/`、`home/` 和 `architecture.md` 为准。

完整验证使用：

```bash
scripts/check.sh
```

该入口先执行结构回归测试，再检查 Darwin inputs 是否已经进入 `flake.lock`，最后真实求值四个系统 host 和 generic Linux Home Manager 输出。
