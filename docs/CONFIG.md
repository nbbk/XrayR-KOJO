# 配置示例说明

仓库提供三份完整、脱敏的单节点示例：

- [HTTP 自动证书](../config/examples/config-http.yml)：不需要 DNS API Token，但域名必须直连 VPS，公网 80 端口必须可用。
- [Cloudflare DNS 自动证书](../config/examples/config-dns-cloudflare.yml)：支持通配符证书，需要最小权限的 DNS API Token。
- [REALITY](../config/examples/config-reality.yml)：不申请传统 TLS 证书，需要生成并填写 REALITY 密钥和 ShortId。

## 使用方法

先备份当前配置：

```bash
xrayr backup
```

选择一种示例作为 `/etc/XrayR/config.yml` 的基础，然后至少替换：

- `PanelType`
- `ApiHost`
- `ApiKey`
- `NodeID`
- `NodeType`
- 示例中的域名、邮箱、Token 或 REALITY 参数

完成后重启并检查：

```bash
xrayr restart
xrayr status
journalctl -u XrayR.service -n 100 --no-pager -o cat
```

## 安全提醒

- 不要把真实 `ApiKey`、DNS Token、私钥或完整运行配置提交到 GitHub。
- Cloudflare Token 应限制到目标 Zone，并仅授予 DNS 编辑和 Zone 读取权限。
- HTTP 证书申请失败时不要连续重启，以免触发 Let’s Encrypt 限流。
- REALITY 的私钥不得填写到客户端；客户端使用对应公钥。

生成 REALITY 密钥对：

```bash
/usr/local/XrayR/XrayR x25519
```
