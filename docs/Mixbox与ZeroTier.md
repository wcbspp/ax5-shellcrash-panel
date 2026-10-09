# Mixbox、Entware 与 ZeroTier

Mixbox 来源：[monlor/MIXBOX-ARCHIVE](https://github.com/monlor/MIXBOX-ARCHIVE)。源码仓库已归档，安装资源在 [monlor/mbfiles](https://github.com/monlor/mbfiles)。

## 仍可下载的源

2026-10-10 检查：以下两个源的 install.sh 内容相同；jsDelivr 的 Mixbox、Entware、ZeroTier ARM 插件包下载和解压通过。AX5 也能直接下载该安装脚本。

- jsDelivr：`https://cdn.jsdelivr.net/gh/monlor/mbfiles`
- GitHub：`https://raw.githubusercontent.com/monlor/mbfiles/master`

仓库列出的 g.monlor.com 本次 TLS 连接失败，不作为推荐入口。下载可用不代表在任意固件上完成过全新安装；本项目实机验证的是已有 Mixbox 环境和 ZeroTier 修复、更新、重启恢复。

## 未安装 Mixbox 的设备

SSH 登录后下载官方安装脚本，再按脚本提示选择持久存储目录：

```sh
export MB_URL=https://cdn.jsdelivr.net/gh/monlor/mbfiles
curl -fsSL "$MB_URL/install.sh" -o /tmp/mixbox-install.sh
sh /tmp/mixbox-install.sh
. /etc/profile
mixbox
```

在 Mixbox 菜单安装并启用 **Entware**，再安装 **ZeroTier**。Entware 下载 ARMv7 软件源，ZeroTier 插件通过 opkg 安装程序。AX5 实测软件源为 `https://bin.entware.net/armv7sf-k3.2/`，当前检查 ZeroTier 包版本为 1.16.0-2。

**已安装设备不要重新运行安装脚本并选择清除。** 更新或修改前保存身份和网络配置，否则可能需要重新授权。

## Entware 挂载检查

归档 Entware 脚本使用了 `mount -o blind`，正确参数应为 `mount -o bind`。这台 AX5 的 /opt 与 Mixbox 持久目录没有绑定，且两边程序、运行库版本不同。不能将旧 /opt 直接删除，也不能在已有身份配置时直接盖上挂载。

首次安装前检查 `apps/entware/scripts/entware.sh` 中的挂载参数，修正拼写后再启用 Entware；检查挂载结果和 `/opt/bin/opkg` 是否来自预期目录。对于已有环境，应先备份两套目录、确认使用中的运行库和身份，再安排迁移。本项目没有将这一归档脚本当作适用于所有固件的一键安装器。

## 应用本项目的修复

1. 将 `zerotier/zerotier.sh` 覆盖到 `/etc/mixbox/apps/zerotier/scripts/zerotier.sh`，设置可执行权限。
2. 在实际 ZeroTier 数据目录的 local.conf 中合并 `settings.portMappingEnabled=false`。已有其他设置继续保留。
3. 在 Mixbox 中填写自己的网络 ID，启动服务，到 ZeroTier Central 授权设备。
4. 执行 `/opt/bin/zerotier-cli info` 和 `/opt/bin/zerotier-cli listnetworks`，分别确认 ONLINE、目标网络 OK。

设备 identity.secret、identity.public、networks.d 和 moons.d 必须保留。被删除过的成员可能需要在 Central 手动添加原设备 ID，而不是重建身份。

## 本次实机结果

ZeroTier 1.14.1 出现过段错误，关闭自身 UPnP/NAT-PMP 端口映射后恢复。更新为官方 ARMv7 包对应的 1.16.0，保留设备身份；两次整机重启后均恢复 ONLINE / OK，Moon 连接正常。

当前运行入口指向 Mixbox 的持久程序，仍使用 /opt 中已验证的运行库和原数据目录。两套运行库内容不同，因此没有整体移除；只清理旧程序、闲置 locale 数据及可重新下载的软件索引。K2P 固件内置 ZeroTier 属于另一种 MIPS/uClibc 环境，不能复用这里的 ARMv7 程序。
