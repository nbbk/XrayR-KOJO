# XrayR-KOJO

自维护版 XrayR 一键安装与管理仓库。

> 说明：XrayR 本体源自原开源项目。本仓库主要维护安装、更新、systemd、配置备份与管理脚本，便于在上游停止维护后继续自行部署。请保留并遵守原项目许可证与版权声明。

## 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/nbbk/XrayR-KOJO/main/install.sh)
```

> 首次使用前，必须先在本仓库 Releases 发布至少一个版本，例如 `v0.9.4`，并上传对应的 `XrayR-linux-*.zip`。详见 `docs/RELEASE.md`。

安装完成后使用：

```bash
xrayr
```

管理菜单使用数字选择功能，运行状态显示在菜单底部。卸载程序后会保留管理脚本，可以再次运行 `xrayr` 并选择“安装 XrayR”。

或直接：

```bash
xrayr install
xrayr start
xrayr stop
xrayr restart
xrayr status
xrayr log
xrayr config
xrayr update
xrayr version
xrayr backup
xrayr restore
xrayr open-ports
xrayr uninstall
```

## 目录

- 程序：`/usr/local/XrayR/XrayR`
- 配置：`/etc/XrayR/config.yml`
- systemd：`/etc/systemd/system/XrayR.service`
- 管理脚本：`/usr/bin/XrayR` 与 `/usr/bin/xrayr`
- 配置备份：`/etc/XrayR/backups/`

## 支持架构

安装器会自动识别常见 Linux 架构并映射到 Release 资产：

- `x86_64` / `amd64` → `XrayR-linux-64.zip`
- `i386` / `i686` → `XrayR-linux-32.zip`
- `aarch64` / `arm64` → `XrayR-linux-arm64-v8a.zip`
- `armv7l` → `XrayR-linux-arm32-v7a.zip`
- `armv6l` → `XrayR-linux-arm32-v6.zip`
- `armv5*` → `XrayR-linux-arm32-v5.zip`
- `mips` → `XrayR-linux-mips32.zip`
- `mipsel` → `XrayR-linux-mips32le.zip`
- `mips64` → `XrayR-linux-mips64.zip`
- `mips64el` → `XrayR-linux-mips64le.zip`
- `ppc64le` → `XrayR-linux-ppc64le.zip`
- `riscv64` → `XrayR-linux-riscv64.zip`
- `s390x` → `XrayR-linux-s390x.zip`

## v0.9.4 Release 快速发布

仓库已经包含 Windows 发布助手：

```text
tools/release.ps1 v0.9.4
```

它默认读取：

```text
C:\Users\Administrator\Desktop\XrayR v0.9.4
```

脚本会根据版本自动读取同名目录，扫描 ZIP、生成 `SHA256SUMS.txt`，并使用 GitHub CLI 创建或更新 `nbbk/XrayR-KOJO` 的 Release。

## 更新策略

`xrayr update` 会：

1. 查询本仓库最新 Release。
2. 自动选择当前 CPU 对应的 ZIP。
3. 备份当前二进制和 `/etc/XrayR` 配置。
4. 替换程序文件。
5. 重启并检查服务。
6. 若启动失败，自动恢复旧二进制和配置。

更新不会覆盖已有 `config.yml`。

## 放行所有端口

保留 `xrayr open-ports` 功能。该操作会显著降低服务器防火墙保护级别，因此脚本会：

- 显示高风险警告；
- 要求输入 `y` 明确确认；
- 尽量备份现有 iptables/ip6tables/nftables 规则；
- 仅在用户主动执行时运行；
- 输出 iptables、ip6tables、nftables 的恢复命令，并提供 `xrayr restore-firewall` 尝试恢复最近的 IPv4 iptables 备份。

## 自动校验

`.github/workflows/validate.yml` 会检查 `install.sh` 与 `scripts/xrayr` 的 Bash 语法，并确认核心安装路径与仓库依赖没有重新指向旧上游。

## 许可证

XrayR 本体版权和许可证归原项目及其贡献者所有。本仓库保留 MPL-2.0 许可证，并提供对应源码归档的 Release 发布方式。
