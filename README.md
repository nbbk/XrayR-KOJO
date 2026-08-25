# XrayR-KOJO

自维护版 XrayR 一键安装与管理仓库。目前提供 `v0.9.4` 多架构 Release、中文数字管理菜单、配置备份、失败回滚与 SHA256 校验。

> XrayR 本体源自原开源项目。本仓库主要维护安装、更新、systemd 和管理脚本。请遵守原项目许可证并保留版权声明。

## 使用条件

- 使用带有 systemd 的 Linux VPS，并以 `root` 用户运行；
- 支持 `apt-get`、`dnf` 或 `yum` 软件包管理器；
- VPS 能访问 GitHub；
- 已在兼容面板中创建节点，并取得面板地址、通信密钥和节点 ID。

## 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/nbbk/XrayR-KOJO/main/install.sh)
```

指定版本安装：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/nbbk/XrayR-KOJO/main/install.sh) v0.9.4
```

安装器会自动识别 CPU 架构、下载本仓库 Release、验证 `SHA256SUMS.txt`，并安装 systemd 服务和管理脚本。

首次安装后必须填写面板参数：

```bash
xrayr config
xrayr restart
xrayr status
```

如果配置尚未完成，首次安装后服务没有启动属于正常现象。查看错误日志：

```bash
journalctl -u XrayR.service -n 100 --no-pager -o cat
```

## 数字管理菜单

直接运行：

```bash
xrayr
```

菜单使用数字选择功能，当前运行状态显示在菜单底部。支持启动、停止、重启、日志、配置、更新、备份、恢复、卸载、重新安装和防火墙管理。

也可以直接使用命令：

```text
xrayr install                         安装 XrayR
xrayr start                           启动
xrayr stop                            停止
xrayr restart                         重启
xrayr status                          查看状态
xrayr log                             查看实时日志
xrayr config                          编辑配置
xrayr update [版本]                   更新程序
xrayr version                         查看版本
xrayr enable                          设置开机自启
xrayr disable                         取消开机自启
xrayr backup                          备份配置
xrayr restore [备份文件]              恢复配置
xrayr update-shell                    更新管理脚本
xrayr open-ports                      放行所有网络端口（高风险）
xrayr restore-firewall [备份文件]     恢复 IPv4 iptables 规则
xrayr uninstall                       卸载程序
```

卸载时可以选择是否删除 `/etc/XrayR`。管理脚本会被保留，因此卸载后仍可运行 `xrayr`，再选择“安装 XrayR”。

## 主要路径

- 程序：`/usr/local/XrayR/XrayR`
- 配置：`/etc/XrayR/config.yml`
- systemd：`/etc/systemd/system/XrayR.service`
- 管理脚本：`/usr/bin/XrayR`、`/usr/bin/xrayr`
- 配置备份：`/etc/XrayR/backups/`

## HTTP 自动申请证书

不使用 Cloudflare Token 时，可以在对应节点中使用 HTTP-01：

```yaml
CertConfig:
  CertMode: http
  CertDomain: "node.example.com"
  CertFile: ""
  KeyFile: ""
  Provider: ""
  Email: "admin@example.com"
  DNSEnv: {}
```

必须确保：

- 域名 A 记录指向当前 VPS；
- 错误的 AAAA 记录已经删除；
- 公网 TCP 80 已放行且没有被其他程序占用；
- 使用 Cloudflare 时，建议申请期间切换为“仅 DNS”；
- HTTP 模式不能申请通配符证书。

申请失败时不要连续重启，否则可能触发 Let’s Encrypt 授权失败限制。先执行 `systemctl stop XrayR`，修复域名或端口后再重试。

## 完整配置示例

仓库提供三份脱敏的完整单节点配置：

- [HTTP 自动证书配置](config/examples/config-http.yml)
- [Cloudflare DNS 自动证书配置](config/examples/config-dns-cloudflare.yml)
- [REALITY 配置](config/examples/config-reality.yml)

字段替换方法和安全说明见 [docs/CONFIG.md](docs/CONFIG.md)。不要把真实面板密钥、DNS Token 或 REALITY 私钥提交到 GitHub。

## 支持架构

安装器会把系统架构映射到对应 Release ZIP：

- `x86_64` / `amd64` → `XrayR-linux-64.zip`
- `i386` / `i686` → `XrayR-linux-32.zip`
- `aarch64` / `arm64` → `XrayR-linux-arm64-v8a.zip`
- `armv7l` → `XrayR-linux-arm32-v7a.zip`
- `armv6l` → `XrayR-linux-arm32-v6.zip`
- `armv5*` → `XrayR-linux-arm32-v5.zip`
- `mips` / `mipsel` → `XrayR-linux-mips32.zip` / `XrayR-linux-mips32le.zip`
- `mips64` / `mips64el` → `XrayR-linux-mips64.zip` / `XrayR-linux-mips64le.zip`
- `ppc64le` → `XrayR-linux-ppc64le.zip`
- `riscv64` → `XrayR-linux-riscv64.zip`
- `s390x` → `XrayR-linux-s390x.zip`

## 更新、备份与回滚

`xrayr update` 会查询本仓库最新 Release，自动选择架构并验证 SHA256。更新前会备份程序和 `/etc/XrayR`，不会覆盖已有的 `config.yml`。如果新版本无法启动，会自动恢复旧程序和配置。

建议修改配置前主动备份：

```bash
xrayr backup
xrayr restore
```

## 放行所有端口

`xrayr open-ports` 会尝试停用 UFW/firewalld，并清空 iptables、ip6tables 和 nftables 过滤规则。这会显著降低 VPS 的安全性，不建议作为常规配置方式。

执行前脚本会备份现有规则，输入 `y` 后才会继续，并输出 IPv4、IPv6 和 nftables 恢复命令。恢复最近的 IPv4 iptables 备份可以运行：

```bash
xrayr restore-firewall
```

## 发布新版本

Windows 发布工具使用 UTF-8 BOM 保存。把 ZIP 放入与版本同名的目录，例如：

```text
C:\Users\Administrator\Desktop\XrayR v0.9.4
```

然后在仓库根目录运行：

```powershell
.\tools\release.ps1 v0.9.4
```

工具会扫描 ZIP、生成 `SHA256SUMS.txt`，并创建或更新 `nbbk/XrayR-KOJO` 的 GitHub Release。详细说明见 [docs/RELEASE.md](docs/RELEASE.md)。

## 常见问题

### 服务不断重启

```bash
systemctl stop XrayR
journalctl -u XrayR.service -n 150 --no-pager -o cat
```

先查看最早出现的 `error` 或 `panic`，不要只看 Go 调用堆栈末尾。

### 检查 80 端口

```bash
ss -lntp | grep ':80 '
```

### 更新管理菜单

```bash
xrayr update-shell
```

## 自动检查

`.github/workflows/validate.yml` 会检查 Bash 语法，并确认核心安装路径和仓库地址没有重新指向旧上游。

## 许可证

XrayR 本体版权和许可证归原项目及其贡献者所有。本仓库保留 MPL-2.0 许可证，并提供对应源码归档的 Release 发布方式。
