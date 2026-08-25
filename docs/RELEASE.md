# XrayR-KOJO Release 发布说明

本仓库的安装脚本只从 `nbbk/XrayR-KOJO` 自己的 GitHub Releases 下载二进制，不再依赖已经停止维护的上游仓库。

## v0.9.4 首次发布

在 GitHub 仓库页面打开：

`Releases` → `Draft a new release`

Tag 填：

```text
v0.9.4
```

Release title 建议：

```text
XrayR-KOJO v0.9.4
```

建议同时上传源码归档，便于长期备份并满足开源许可证的源码可获得性要求：

```text
XrayR-0.9.4.tar.gz
XrayR-0.9.4.zip
```

至少上传最常用 Linux 二进制：

```text
XrayR-linux-64.zip
XrayR-linux-arm64-v8a.zip
XrayR-linux-arm32-v7a.zip
```

如果希望保留完整多架构支持，可上传：

```text
XrayR-linux-32.zip
XrayR-linux-64.zip
XrayR-linux-arm32-v5.zip
XrayR-linux-arm32-v6.zip
XrayR-linux-arm32-v7a.zip
XrayR-linux-arm64-v8a.zip
XrayR-linux-mips32.zip
XrayR-linux-mips32le.zip
XrayR-linux-mips64.zip
XrayR-linux-mips64le.zip
XrayR-linux-ppc64le.zip
XrayR-linux-riscv64.zip
XrayR-linux-s390x.zip
```

用户本地当前文件目录：

```text
C:\Users\Administrator\Desktop\XrayR v0.9.4
```

该目录中的 Windows、macOS、FreeBSD 等包也可以一起上传保存，但 Linux 一键安装脚本只会自动选择 `XrayR-linux-*.zip`。

## 发布后验证

普通 AMD64 / x86_64 VPS：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/nbbk/XrayR-KOJO/main/install.sh)
```

Oracle ARM / ARM64 VPS：安装器会自动选择：

```text
XrayR-linux-arm64-v8a.zip
```

安装完成后检查：

```bash
xrayr version
xrayr status
xrayr log
```

首次安装若面板参数尚未配置：

```bash
xrayr config
xrayr restart
```

## 以后发布新版本

保持资产命名规则不变，例如：

```text
v0.9.5
└── XrayR-linux-64.zip
└── XrayR-linux-arm64-v8a.zip
...
```

服务器执行：

```bash
xrayr update
```

会自动查找最新 Release。指定版本可执行：

```bash
xrayr update v0.9.4
```

## 重要原则

- 不覆盖 `/etc/XrayR/config.yml`。
- 更新前自动备份程序与配置。
- 新版本启动失败时自动回滚。
- 不要再次把本仓库设置成上游 Fork 的自动同步目标。
- Release 二进制应对应可获得的源代码快照，并保留原项目许可证与版权信息。
