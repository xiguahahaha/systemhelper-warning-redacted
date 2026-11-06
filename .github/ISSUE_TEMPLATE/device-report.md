---
name: 设备自查报告
about: 报告你的设备上是否发现该应用，帮助判断预装范围
title: "[设备报告] 厂商/型号 - 是否发现 SystemHelper"
labels: ""
assignees: ""
---

## 设备信息

- 厂商/型号：
- Android 版本：
- ROM/系统版本：
- 是否为运营商定制机/合约机：
- 是否 root：

## 自查结果

请粘贴以下命令的输出（删除手机号、IMEI 等个人信息）：

```text
adb shell pm path com.mobiletools.systemhelper
adb shell pm list packages -i | grep systemhelper
adb shell dumpsys package com.mobiletools.systemhelper | grep -E "versionName|codePath|flags|installerPackageName|firstInstallTime"
```

## 其他说明

- 应用是否在 `/system`、`/product` 等系统分区：
- 是否在 `/data/app`（后装）：
- 是否看到发往运营商 DM 域名的网络请求（如抓包）：
- 其他异常：
