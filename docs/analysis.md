# 详细技术分析

> 本文是 [README](../README.md) 的技术附录。类名/jadx 文件名来自反编译产物，**不是原始代码的真实类名**；原始应用只保留了 `com.mobiletools.systemhelper` 包名和组件名，其余工具类被混淆为 `a/b/c/...`。

## 1. 应用结构

| 路径 | 作用 |
|---|---|
| `com.mobiletools.systemhelper.control.DMApplication` | Application 入口，调用 `f1.a.u()` 注册电话状态监听 |
| `com.mobiletools.systemhelper.control.OnBootReceiver` | 开机广播；延迟 4 分钟后触发 `B`/`F` 上报 |
| `ScheduleRegisterReceiver` | 定时 `S` 上报 |
| `AppInfoRegisterReceiver` | 定时 `A` 上报应用画像 |
| `SignalInfoRegisterReceiver` | 定时 `R` 上报信号/位置批量 |
| `GetSignalInfoReceiver` | 每 30 分钟定位+信号采样，写本地 SQLite |
| `SIMStateReceiver` | SIM 状态变化，触发 `T` |
| `ConnectStateReceiver` | 网络变化监听（仅注册/日志） |
| `RegisterHelperService` | **导出** Binder 服务，可改服务器/周期/日志 |
| `RegisterIntentService` | 空壳 IntentService |
| `RegisterJobService` | JobService 空壳 |
| `Activity.TestActivity` | **导出** 调试 Activity，显示设备 JSON |

### 启动链路

```java
// DMApplication.onCreate()
h.a("DMApplication", "onCreate--->");
a.u(this); // f1.a.u：注册双卡 TelephonyCallback
```

`f1.a.u(Context)` 在 `isUserPermissionOpen == true` 时：

- 通过 `SubscriptionManager.getSubId(0/1)` 取 subId
- 为每张卡创建 `TelephonyManager.createForSubscriptionId(subId)`
- 注册 `e1.a`（TelephonyCallback，监听呼叫断开原因、精确数据连接状态）

### 开机链路

```java
// OnBootReceiver.onReceive()
if (BOOT_COMPLETED || QUICKBOOT_POWERON) {
    g1.a.b(context, 240000L);              // 4 分钟后再次触发自己
    g1.a.c(context, l.m(context));         // 30 分钟后 GetSignalInfo
    g1.a.f(context, l.h(context), l.l(context)); // R 定时
    g1.a.e(context, l.g(context), l.j(context)); // S 定时
    g1.a.a(context, l.f(context), l.c(context)); // A 定时
    return;
}
// 第二次进入（action=null）：
new SIMStateReceiver().b(context);
new ConnectStateReceiver().b(context);
o.f();
if (o.e(context) != null) {
    String first = l.n(context, "firstPowerOn", "");
    if (!first.isEmpty()) b.a(context, "B");
    else { b.a(context, "F"); l.G(context, "firstPowerOn", "firstPowerOn"); }
}
```

### 定时器

`g1.a` 全部使用 `AlarmManager.setExactAndAllowWhileIdle(2, ...)`（`ELAPSED_REALTIME_WAKEUP`），PendingIntent 指向对应 BroadcastReceiver。

默认周期（`g1.d`）：

| 常量 | 默认值 | 含义 |
|---|---|---|
| `f2655m` | `Random.nextInt(86400000)` | AppInfo 初始随机偏移 |
| `f2656n` | `Random.nextInt(86400000)` | Schedule 初始随机偏移 |
| `f2657o` | `Random.nextInt(86400000)` | Signal 初始随机偏移 |
| `f2661s` | 86400000 | `S` 周期 24h |
| `f2662t` | 86400000 | `A` 周期 24h |
| `f2663u` | 43200000 | `R` 周期 12h |
| `f2664v` | 1800000 | 定位采样周期 30min |

`RegisterHelperService` 的 `a(int)` 会按比例改写这些周期（`i2*8/5`、`i2*4/5`、`i2*6/5`、`i2*3/5`），进一步说明它是可被外部配置的。

---

## 2. 设备信息采集（`e1.b` + `f1.*`）

`e1.b` 是一个纯数据对象，`b()` 把它序列化成 JSON。字段与含义见 README 第 4 节。`f1.o.d(context, regType)` 是编排入口：

1. `k(context, bVar)`：读取基础设备信息 + 当前网络类型
2. `i()/j()`：比较 `iccid1/iccid2` 是否变化（`T` 类型用）
3. `l(bVar)`：双卡数据交换/脱敏
4. 根据 `regType` 选择线程：
   - `A`：`e1.f`（应用画像）→ `e1.c`/`e1.g`
   - `R`：`g1.m` 取信号批量 → `e1.c`/`e1.g`
   - `B/F/S/T`：`e1.c`（IPv6）或 `e1.g` 直接上报

### 按厂商分支

`f1.o.e(Context)` 读取 `ro.product.manufacturer`，按厂商返回不同的 `DeviceInfoReader`：

| 厂商 | 类 | 特点 |
|---|---|---|
| 通用 | `f1.a` | 基础读取；`vivo` 下有反射分支 |
| Xiaomi | `f1.m` | MIUI 版本、`getImeiForSlot` 反射、`ro.miui.cust_hardware` |
| OPPO | `f1.d` | `ro.build.hardware.version` |
| vivo | `f1.k` | `ro.vivo.hardware_version`、`ro.vivo.op.entry`（含定制运营商标记时用 op 版本；标记值已脱敏）、`operator_service_improve_plan` 开关 |
| Samsung | `f1.h` | `ril.sw_ver` / `ril.hw_ver` |
| realme | `f1.g` | 基础 |
| ZTE | `f1.n` | 基础 |
| nubia | `f1.c` | 基础 |
| OnePlus | `e` | 基础 |
| Liantong | `f1.b` | 基础 |
| TDTECH | `i` | 基础 |
| PTAC | `f` | 基础 |
| WIKO | `f1.l` | `switch_dual_card_slots` 决定 IMEI 槽位 |
| Tianyi | `f1.j` | 基础 |

> 这种按厂商分支的写法是运营商定制 ROM 的典型做法，普通 App 不会为 13 个厂商分别适配 IMEI/版本读取。

### 双卡与 eSIM

- `IMEI1/2`：`TelephonyManager.getImei(0/1)`；小米走 `miui.telephony.TelephonyManager.getImeiForSlot`
- `ICCID1/2`：`getSimSerialNumber()`
- `IMSI1/2`：`getSubscriberId()`
- `MNC1/2`：`getSimOperator()` / `getNetworkOperator()`
- `TAC/CID/PCI`：`ServiceState` → `NetworkRegistrationInfo` → `CellIdentityLte` / `CellIdentityNr`
- `NetworkType`：`LTE` / `NSA`（`isEnDcAvailable=true`）/ `SA` / `GSM` / `WCDMA` / `TD-SCDMA` / `CDMA`
- `VoNREnable`：`NetworkRegistrationInfo.toString().contains("mVopsSupport = 1")`
- `VoLTE`：`ImsManager.getImsMmTelManager(subId).isAdvancedCallingSettingEnabled()`
- `5G 开关`：vivo 走 `API_TAG_getNRSwitchState` 反射；其他走 `persist.vendor.radio.5g_mode_pref` / `persist.radio.vivo.fiveg` 属性
- `eSIM`：`SubscriptionInfo.isEmbedded()` + `getMccString/getMncString`
- `BSSID`：`WifiManager.getConnectionInfo().getBSSID()`，未连接时写 `NWC`
- `IPv6`：`NetworkInterface` 枚举非 loopback/非 link-local 的 `Inet6Address`
- `RAM/ROM/FREE`：`g1.g`，优先 `ro.boot.dram_info`，否则 `ActivityManager.MemoryInfo`

### 脱敏逻辑

`f1.o.l(bVar)` 和 `e1.d` 里对 IMSI/ICCID 做部分打码，但条件是：

```java
!g1.l.u(imsi) // 不是 460xx（具体 MNC 已脱敏） 开头
```

也就是说，**非该运营商 SIM 卡会打码，该运营商 SIM 卡不打码**。IMEI 始终是完整值。

---

## 3. 信号采集（`e1.d` / `e1.a`）

`e1.d` 负责单卡信号：

- `ServiceState.getNetworkRegistrationInfoList()` 过滤 `domain=2 && transportType=1`（PS + 蜂窝）
- `CellIdentityLte`：`getCi/getTac/getPci/getBands/getBandwidth`
- `CellIdentityNr`：`getNci/getTac/getPci/getBands/getNrarfcn`
- `SignalStrength`：
  - NR：`getSsRsrp/getSsRsrq/getSsSinr/getCsiCqiTableIndex/getCsiCqiReport`
  - LTE：`getRsrp/getRsrq/getRssnr/getCqiTableIndex/getCqi`
- `CallDisconnectCause` / `DataFailCause`：`e1.a` 的 `TelephonyCallback` 回调，映射成可读字符串（`g1.n` 的 `z/A` 字段）
- `EPSFallback`：`B` 字段（代码中未完整赋值，可能由其它路径填充）

`GetSignalInfoReceiver` 在每次定位回调里：

1. 设置 `signalInfo.D/E/F = 经度/纬度/海拔`
2. 对 slot 0/1 分别调用 `new e1.d().e(context, slot, signalInfo)`
3. 把 `signalInfo.a()` 的 JSON 插入 `signalhelper` 数据库（最多 100 条）
4. 通过 `e(nVar)` 检查 `MNCCH` 是否以 `460` 开头，只存中国网络的数据

---

## 4. 应用画像（`e1.f`）

`e1.f` 是 `A` 类型的核心：

- `PackageManager.getInstalledApplications(0)` 拿全部已安装应用
- `UsageStatsManager.queryAndAggregateUsageStats(now-24h, now)` 拿使用统计
- 按 `getTotalTimeInForeground()` 降序排序
- 对每个 `UsageStats`：
  - `pkgName`、`appLabel`
  - `runTime`（分钟）
  - 用 `NetworkStatsManager.querySummary(0, imsi1, start, end)` 统计卡 1 流量
  - 用 `querySummary(0, imsi2, ...)` 统计卡 2 流量
  - 用 `querySummary(1, null, ...)` 统计 WiFi 流量
- `f1.o.a()` 里过滤了 `pkgName.startsWith("com.android")` 的包；**最近 24 小时有使用记录的第三方应用会保留**（不是无差别枚举所有已安装应用）

> 拿到的是“哪个 App 用了多久、用了多少流量”，不是 App 内容。Android 普通/特权应用都无法读取其他 App 的聊天数据库（除非 root 或无障碍）。

---

## 5. 位置采集（百度 LBS）

`GetSignalInfoReceiver.d(b1.b)`：

```java
g.r0(true);
g gVar = this.f2193c;
gVar.n0(bVar);
b1.h hVar = new b1.h();
hVar.k("bd09ll");              // 坐标系
hVar.m(h.b.Hight_Accuracy);    // 高精度
hVar.o(true);                  // 需要地址？/GPS？
hVar.p(0);                     // 单次定位
hVar.l(true);
gVar.s0(hVar);
gVar.t0();                     // start
```

- `b1.*` 是百度定位 SDK 的客户端封装；`com.baidu.location.Jni` 加载 `liblocSDK8b.so`
- `libindoor.so` 是百度室内定位
- 百度 SDK 自身会向 `api.map.baidu.com`、`loc.map.baidu.com`、`ofloc.map.baidu.com` 等发起请求
- 应用自己只把定位结果写入 `signalhelper`，等 `R` 时随 `SigInfo` 发给运营商

---

## 6. 加密与 HTTP

### 密钥/证书

- `assets/pub.cer`：X.509，Subject/Issuer `C=CN, O=[REDACTED], CN=[REDACTED]`，**1024-bit RSA**，有效期 2019-05-24 至 2119-04-30
- APK 签名证书：`C=86, O=[REDACTED], OU=[REDACTED], CN=[REDACTED]`，2048-bit RSA，2019-2069

### 加密流程

```java
// g1.c
public static byte[] a(String str, byte[] bArr) { // AES
    SecretKeySpec key = new SecretKeySpec(bArr, "AES");
    Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
    cipher.init(Cipher.ENCRYPT_MODE, key);
    return cipher.doFinal(str.getBytes("utf-8"));
}
public static byte[] d(String str) { // MD5
    return MessageDigest.getInstance("MD5").digest(str.getBytes("UTF-8"));
}
public static byte[] c(Context context, byte[] bArr) { // RSA
    InputStream in = context.getResources().getAssets().open("pub.cer");
    return new g1.j().a(new g1.j().b(in), bArr);
}
```

`g1.j.a` 使用 `RSA/ECB/PKCS1Padding`。

### HTTP

`g1.f.b(path, body, md5)`：

- `http://` 时用 `HttpURLConnection`，`https://` 时用 `HttpsURLConnection`
- 连接/读取超时 10s/15s
- `Content-Type: application/encrypted-json`
- 只判断 `responseCode == 200`；`416` 在调用方被视为成功
- **不读取响应体**

### URL 构造

```java
String str = l.k(context) + "?ver=5.0&model=" + URLEncoder.encode(bVar.f2448b, "utf-8")
           + "&manuf=" + URLEncoder.encode(bVar.f2447a, "utf-8")
           + "&sign=" + encode;
```

`l.k(context)` 默认 `g1.d.f2654l = "http://dm.operator.example:18080/register"`，但会优先读 SharedPreferences 的 `serverAddress`（可被导出 Service 改写）。

---

## 7. 本地存储与重试

### `g1.e`（`systemhelper` 数据库）

- 表：`dmregister (ID integer primary key autoincrement, jsonString text)`
- 每次插入前，如果行数 > 10，删除最旧的若干条
- `c()` 取最新一条并删除，返回 `JSONObject`
- 用途：上报失败的历史记录，下次 `e1.e` 线程重试

### `g1.m`（`signalhelper` 数据库）

- 表：`signal (ID integer primary key autoincrement, jsonString text)`
- 最多 100 条，超出删最旧
- `R` 上报时 `d()` 全量读出为 `JSONArray`，然后 `a()` 清空

### SharedPreferences

文件名：`com_mobiletools_systemhelper_preference`

键：

- `iccid1` / `iccid2`：上次看到的 ICCID，用于检测 SIM 变化
- `firstPowerOn`：是否首次开机
- `serverAddress`：**可被导出 Service 改写**
- `scheduleInterval` / `scheduleInterval2`
- `appInfoInterval` / `appInfoInterval2`
- `signalInfoInterval` / `signalInfoInterval2`
- `GetsignalInfoInterval`
- `preference_enable_log`

`g1.l.b()` 会直接删除 `/data/data/com.mobiletools.systemhelper/shared_prefs/com_mobiletools_systemhelper_preference.xml`。

---

## 8. 导出组件细节

### `RegisterHelperService`

Manifest：

```xml
<service android:exported="true"
         android:name="com.mobiletools.systemhelper.service.RegisterHelperService">
    <intent-filter>
        <action android:name="com.mobiletools.systemhelper.service.IRegisterHelperService"/>
    </intent-filter>
</service>
```

`onBind()` 直接 `return new a()`，**没有 `checkCallingPermission` / `getCallingPackage` / 签名校验**。

AIDL 风格事务：

| transaction | 方法 | 实际效果 |
|---|---|---|
| 1 | `c(String)` | `l.D()` → 写 `serverAddress` |
| 2 | `a(int)` | 写多个 interval |
| 3 | `e()` | `l.b()` → 删除 SharedPreferences 文件 |
| 4 | `d(boolean)` | 写 `preference_enable_log` + 改 `d.f2643a` |
| 5 | `b()` | 读 `preference_enable_log` |

任何应用都可以用显式 `ComponentName` bind，然后调用上述事务。由于没有权限保护，这是本样本最严重的实现缺陷。

### `TestActivity`

```xml
<activity android:exported="true"
          android:name="com.mobiletools.systemhelper.Activity.TestActivity">
    <intent-filter>
        <action android:name="com.mobiletools.systemhelper.activity.testactivity"/>
        <category android:name="android.intent.category.DEFAULT"/>
    </intent-filter>
</activity>
```

`onCreate` 检查 5 个运行时权限，缺权限就 `requestPermissions`；但 `onRequestPermissionsResult` 里用 `iArr.length == 3` 判断，和请求的 5 个权限不一致，授权后可能直接 `finish()`。这是明显的调试残留。

### 广播

- `OnBootReceiver`：`exported=true`，filter `BOOT_COMPLETED`/`QUICKBOOT_POWERON`
- `SIMStateReceiver`：`exported=true`，filter `SIM_STATE_CHANGED`
- `ConnectStateReceiver`：`exported=true`，filter `CONNECTIVITY_CHANGE`
- 其余 Receiver：未显式 `exported`，默认 false（仅应用内/系统可发）

`BOOT_COMPLETED` 是 protected broadcast，普通应用不能直接发送；但显式 Intent（不带 action）仍可命中 `OnBootReceiver`，从而触发 `B`/`F` 上报路径。`SIM_STATE_CHANGED`/`CONNECTIVITY_CHANGE` 在不同 Android 版本/ROM 上的保护程度不同，显式 Intent 通常仍可送达。

---

## 9. “是否允许采集”的判断

### `f1.a.c(Context)`（非 vivo）

```java
Boolean valueOf = Boolean.valueOf(
    Settings.Global.getInt(context.getContentResolver(), "device_provisioned", 0) == 1);
return valueOf.booleanValue();
```

只看开机向导是否完成。

### `g1.l.a(Context)`（vivo 路径 / `f1.k.A`）

```java
if (device_provisioned) {
    r2 = Settings.Secure.getInt(cr, "operator_service_improve_plan", 0) == 1;
}
return r2;
```

同时要求 `operator_service_improve_plan == 1`。

### 结果

- `f1.a.b()`：`vivo` → `g1.l.a()`；其他 → `c()`
- `f1.k.b()`：vivo → `A()`
- `GetSignalInfoReceiver.onReceive()`：`vivo` → `b()`（含开关）；其他 → `c()`（只看 `device_provisioned`）
- `e1.d.d()`：`vivo` → `l.a()`

因此，非 vivo 机型关掉“运营商服务改进计划”开关不会阻止采集。这是 README 第 7 节的重点。

---

## 10. 反编译噪声与不确定点

- jadx 对 `e1.b.b()` 的 `SigInfo`/`AppInfo` 条件分支有重复/疑似反转的还原（`if (!P.equals("R") || P.equals(""))` 等）。从 `f1.o.d()` 的赋值看，设计意图是 `R` 带 `SigInfo`、`A` 带 `AppInfo`；实际运行需动态验证。
- `DeviceType` 的 `if (str2 != null || str2.isEmpty())` 也疑似 jadx 控制流还原问题。
- `e1.b.b()` 里 `SubType` 的 `if (N != null) put("") else put(N)` 看起来反了；不确定最终 JSON 是否包含 RAM/ROM/FREE。
- 这些不影响“采集字段集合”“服务器地址”“导出组件”“同意逻辑”等核心结论，但引用具体字段时请注意。
- `GetSignalInfoReceiver` 的 `SPEED/BEARING` 字段在 `g1.n` 中定义，但该路径未明显赋值，可能由其它路径或后续版本填充。

---

## 11. 关键字符串（可用于检测）

```text
com.mobiletools.systemhelper
com.mobiletools.systemhelper.activity.testactivity
com.mobiletools.systemhelper.service.IRegisterHelperService
dm.operator.example:18080/register
application/encrypted-json
com_mobiletools_systemhelper_preference
dmregister
signalhelper
IGY6EFGRsixbYqk7GeZdAOD2Od3Rj7iF
```

以及 JSON 键：

```text
Manuf Model HWVersion SWVersion OS OSVersion
IMEI1 ICCID1 IMSI1 MNC1 NetworkType1 TAC1 CID1 PCI1 VolteEnabled1 5GEnabled1 VoNREnable1
IMEI2 ICCID2 IMSI2 MNC2 NetworkType2 TAC2 CID2 PCI2 VolteEnabled2 5GEnabled2 VoNREnable2
DataSlot BSSID Esim InactiveEsimMNC AccType IPv6 SubType DeviceType
RegType SpecVersion ClientVersion Time SigInfo AppInfo
appLabel pkgName runTime tx1 rx1 tx2 rx2 totalData1 totalData2 totalDataWiFi
LONGITUDE LATITUDE ALTITUDE SPEED BEARING
```
