# AX5 ShellCrash 面板

在小米 AX5 管理页中管理 ShellCrash：切换节点、更新订阅和规则、调整 DNS、启停服务、查看日志和内存。

![面板](docs/面板.png)

## 适用设备

已验证 **Redmi AX5 / RA67，原厂开发版 1.0.105**，需要解锁 SSH 并安装 ShellCrash 1.9.4release。支持 sing-box 与 mihomo；其他固件暂未验证。

## 安装

从 [v1.0.0 下载](https://github.com/wcbspp/ax5-shellcrash-panel/releases/tag/v1.0.0) 源码包，按[安装步骤](docs/部署记录.md)复制页面和服务文件。首次部署还需要自己的代理配置、内核包和规则；已部署设备只更新源码即可。

小米默认管理地址为 `192.168.31.1`。登录路由器后点击 **ShellCrash**，无需另设面板密码。地址改过则使用自己的地址。

## 日常使用

| 页面 | 功能 |
| --- | --- |
| 节点、检测 | 选择节点、三次测速取最短值、网站连通检测 |
| 配置 | 订阅、内核切换、正式版工具更新、自定义镜像 |
| 规则、DNS | 国内 IP 和域名库更新、Fake IP 真实地址例外 |
| 监控、日志 | 内存阈值、安全清理、异常记录、按需 ZeroTier 状态 |

重启优先解压本地内核包，失败再从镜像和工具源恢复。配置单独保存在路由器中，更新内核不会覆盖。手动更新会尝试同步镜像，失败会提示。

当前只使用国内域名库和国内 IP 网段，不需要安装完整 GeoSite。具体见[数据库说明](docs/数据库与规则.md)。

## Mixbox 与 ZeroTier

安装来源与修复方法见[Mixbox、Entware 和 ZeroTier](docs/Mixbox与ZeroTier.md)。已核对可用下载源，保留现有设备身份。

## 验证与源码

已验证 sing-box 1.12.13 / mihomo v1.19.28 切换、两种内核本地恢复、DNS 例外及国内分流。AX5 完整重启后面板、代理和 ZeroTier 恢复。长期高负载仍需观察。[详细测试记录](docs/验证记录.md) · [变更记录](CHANGELOG.md)

公开包不包含私人订阅、密码、设备身份或运行配置。面板基于 padavan-shellcrash-panel，组件许可见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。
