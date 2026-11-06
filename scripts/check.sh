#!/system/bin/sh
# SystemHelper 自查脚本
# 用法：
#   adb push scripts/check.sh /data/local/tmp/
#   adb shell sh /data/local/tmp/check.sh
# 可选（root，查看数据目录）：
#   adb shell su -c 'sh /data/local/tmp/check.sh'

PKG=com.mobiletools.systemhelper
echo "=========================================="
echo " SystemHelper 自查"
echo "=========================================="

echo
echo "[1] 包路径 (pm path)"
pm path "$PKG" 2>/dev/null || true

echo
echo "[2] 安装来源 (pm list packages -i)"
pm list packages -i 2>/dev/null | grep "$PKG" || echo "未找到"

echo
echo "[3] 包信息"
dumpsys package "$PKG" 2>/dev/null | grep -E \
  "versionName|versionCode|codePath|resourcePath|firstInstallTime|lastUpdateTime|installerPackageName|flags|sharedUser|userId" \
  || echo "未找到"

echo
echo "[4] 运行进程"
ps -A 2>/dev/null | grep -i mobiletools || echo "无进程"

echo
echo "[5] 定时任务 (AlarmManager)"
dumpsys alarm 2>/dev/null | grep -i systemhelper | head -20 || echo "无"

echo
echo "[6] JobScheduler"
dumpsys jobscheduler 2>/dev/null | grep -i systemhelper | head -20 || echo "无"

echo
echo "[7] 运营商服务改进计划开关 (vivo 会读)"
settings get secure operator_service_improve_plan 2>/dev/null || echo "读取失败"

echo
echo "[8] 设备管理员"
dumpsys device_policy 2>/dev/null | grep -i systemhelper || echo "无"

echo
echo "[9] 本地数据（需要 root）"
if [ "$(id -u 2>/dev/null)" = "0" ]; then
  ls -la /data/data/com.mobiletools.systemhelper 2>/dev/null || echo "无数据目录"
  ls -la /data/data/com.mobiletools.systemhelper/databases 2>/dev/null || true
  ls -la /data/data/com.mobiletools.systemhelper/shared_prefs 2>/dev/null || true
else
  echo "当前不是 root，跳过（可用 su 重新运行）"
fi

echo
echo "[10] 结论"
if [ -n "$(pm path "$PKG" 2>/dev/null)" ]; then
  echo "已安装。请根据 [1] 的路径判断：/system、/product 等为预装；/data/app 为后装。"
else
  echo "未安装（或已对当前用户卸载）。"
fi
echo
