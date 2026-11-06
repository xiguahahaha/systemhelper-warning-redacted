# 卸载与处置指南

> 卸载系统应用有风险。请先确认 `pm path`、做好备份、确保有 TWRP/救砖方案。操作后果自负。

## 0. 先判断它是怎么装的

```bash
adb shell pm path com.mobiletools.systemhelper
adb shell pm list packages -i | grep systemhelper
adb shell dumpsys package com.mobiletools.systemhelper | grep -E "codePath|resourcePath|versionName|flags|installerPackageName|firstInstallTime"
```

| 路径 | 判断 | 处置 |
|---|---|---|
| `/system/priv-app/...`、`/system/app/...` | 系统预装 | 非 root 可 `pm uninstall --user 0`；root 用 Magisk 模块彻底移除 |
| `/product/priv-app/...`、`/system_ext/...`、`/vendor/...`、`/my_*` | 分区预装/厂商定制 | 同上；模块路径必须镜像实际分区 |
| `/data/app/...` 且 installer 为空/未知 | 后装 | 直接 `pm uninstall`；按恶意软件处置 |
| 空 | 未安装 | 无需处理 |

同时确认没有其它应用与它共享 UID：

```bash
adb shell pm list packages -U | grep com.mobiletools.systemhelper
```

如果只有它自己，放心删。

## 1. 非 root：卸载当前用户 + 清数据

```bash
adb shell am force-stop com.mobiletools.systemhelper
adb shell pm clear com.mobiletools.systemhelper
adb shell pm uninstall --user 0 com.mobiletools.systemhelper

# 如果 uninstall 报 DELETE_FAILED_INTERNAL_ERROR：
adb shell pm disable-user --user 0 com.mobiletools.systemhelper
```

`pm clear` 会删除：

- `databases/systemhelper`（表 `dmregister`）
- `databases/signalhelper`（表 `signal`）
- `shared_prefs/com_mobiletools_systemhelper_preference.xml`

再收权限（部分 ROM 会拒绝/回滚，属正常）：

```bash
adb shell pm revoke com.mobiletools.systemhelper android.permission.ACCESS_FINE_LOCATION
adb shell pm revoke com.mobiletools.systemhelper android.permission.ACCESS_COARSE_LOCATION
adb shell pm revoke com.mobiletools.systemhelper android.permission.ACCESS_BACKGROUND_LOCATION
adb shell pm revoke com.mobiletools.systemhelper android.permission.READ_PHONE_STATE
```

没有 root 时，用 **NetGuard / PCAPdroid**（本地 VPN，免 root）按应用禁网，或在路由器/DNS 拦截该应用实际使用的 DM 域名（需从抓包确认）。

> `pm uninstall --user 0` 只是“对当前用户卸载”，系统分区里的 APK 还在；恢复出厂设置或 `pm install-existing` 后会回来。

## 2. root：Magisk 模块彻底移除（推荐）

原理：不直接改 `/system`，而是在 `/data/adb/modules` 里建一个模块，用 Magisk 的 `.replace` 机制在开机时把目标目录整个替换成空目录。可回滚，不动原文件。

### 2.1 预演

```bash
adb push scripts/remove_magisk.sh /data/local/tmp/
adb shell su -c 'sh /data/local/tmp/remove_magisk.sh'
```

脚本会打印：

- 当前 `pm path`
- 找到的系统目录
- 目录内容
- 将要写入的模块路径
- 将要执行的卸载命令

### 2.2 执行

```bash
adb shell su -c 'sh /data/local/tmp/remove_magisk.sh --apply'
```

脚本会：

1. 备份原目录到 `/sdcard/SystemHelper_backup/<时间戳>/`
2. 在 `/data/adb/modules/systemhelper_remove` 写入 `module.prop` 和 `.replace`
3. `pm clear` + `pm uninstall --user 0`（失败则 `pm disable-user`）
4. 提示重启

重启后验证：

```bash
adb shell pm path com.mobiletools.systemhelper
adb shell pm list packages | grep -i systemhelper
adb shell ps -A | grep -i mobiletools
adb shell dumpsys alarm | grep -i systemhelper
```

全部为空即成功。

### 2.3 回滚

```bash
adb shell su -c 'sh /data/local/tmp/rollback.sh'
```

或手动：

```bash
adb shell su -c 'rm -rf /data/adb/modules/systemhelper_remove'
adb shell su -c 'pm install-existing --user 0 com.mobiletools.systemhelper'
```

然后重启。因为模块只覆盖、不删除原文件，移除模块后系统分区 APK 会自动恢复。

### 2.4 如果模块不生效

不同 root 方案对 `.replace` 的支持不同：

- **Magisk**：支持 `.replace`（推荐）
- **KernelSU / APatch**：多数版本支持 Magisk 模块，但请先确认其 magic mount 对 `.replace` 的实现
- **厂商分区**（`/my_product`、`/my_heytap`、`/preload` 等）：部分 Magisk 版本不覆盖这些分区，需要 TWRP 或直接改分区

可以检查模块是否被加载：

```bash
adb shell su -c 'ls -la /data/adb/modules/systemhelper_remove'
adb shell su -c 'magisk --list 2>/dev/null | grep systemhelper'
```

### 2.5 替代方案：TWRP 直接删除

如果能进 TWRP 且能挂载系统分区：

```bash
# 在 TWRP 终端
mount /system
rm -rf /system/priv-app/SystemHelper
```

Android 10+ 动态分区（`/super`）下 TWRP 可能无法挂载 `/system` 为可写；不要强行操作，优先用 Magisk 模块。

## 3. 残留清理

```bash
# 特权权限白名单（删除应用后留着无害，可选清理）
adb shell su -c 'grep -rl com.mobiletools.systemhelper /system/etc/permissions /product/etc/permissions /system_ext/etc/permissions 2>/dev/null'

# 数据目录（pm clear 通常会处理，双保险）
adb shell su -c 'rm -rf /data/data/com.mobiletools.systemhelper'
adb shell su -c 'rm -rf /data/user/0/com.mobiletools.systemhelper'
adb shell su -c 'rm -rf /data/user_de/0/com.mobiletools.systemhelper'

# 定时任务/设备管理员残留
adb shell su -c 'dumpsys alarm | grep -i systemhelper'
adb shell su -c 'dumpsys jobscheduler | grep -i systemhelper'
adb shell su -c 'dumpsys device_policy | grep -i systemhelper'
```

## 4. 重要注意事项

### 恢复出厂设置

- Magisk 模块在 `/data/adb`，恢复出厂会清空 → 应用会回来。
- 想“永远不回来”，只能：
  - 修改系统镜像 / `/super` 分区（高风险，可能变砖、影响 OTA）
  - 使用不带该应用的自定义 ROM
  - 每次刷机后重新应用模块

### OTA

- A/B 设备通过 Magisk “安装到非活动槽位” 后，模块通常仍在 `/data/adb`，开机重新生效。
- 部分厂商 OTA 会校验系统分区，模块本身不修改分区，一般不影响；但仍建议 OTA 前备份。

### 合约机

- 如果这是某运营商合约机，终端注册数据可能与补贴/激活/白名单绑定；删除前先确认不影响合约权益。
- 一般不影响打电话、上网、短信。

### 救砖

如果重启后无法进入系统：

1. 进 TWRP → 文件管理器 → 删除 `/data/adb/modules/systemhelper_remove`
2. 或在模块目录创建 `disable` 文件
3. 或 `adb shell magisk --remove-modules`（需 adb 可用）

## 5. 验证脚本

```bash
adb push scripts/check.sh /data/local/tmp/
adb shell sh /data/local/tmp/check.sh
```

输出包括：包路径、版本、安装来源、导出组件、运行进程、定时任务、本地数据、同意开关。

## 6. 服务器端数据

卸载只能停止未来采集，**不能删除已经上传的数据**。删除请求流程见 [docs/deletion-request.md](docs/deletion-request.md)。
