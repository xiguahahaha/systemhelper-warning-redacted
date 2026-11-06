#!/system/bin/sh
# 回滚 SystemHelper 的 Magisk 模块移除
# 用法：
#   adb shell su -c 'sh /data/local/tmp/rollback.sh'

PKG=com.mobiletools.systemhelper
MOD=/data/adb/modules/systemhelper_remove

if [ "$(id -u 2>/dev/null)" != "0" ]; then
  echo "错误: 需要 root，请用 su 运行。"
  exit 1
fi

echo "[1] 删除模块 $MOD"
rm -rf "$MOD"

echo "[2] 尝试恢复系统应用"
if pm install-existing --user 0 "$PKG" >/dev/null 2>&1; then
  echo "pm install-existing 成功。"
else
  echo "pm install-existing 失败（可能应用已在当前用户安装，或系统分区副本不存在）。"
fi

echo "[3] 完成。"
echo "请重启设备。若模块已删除，系统分区原始 APK 会自动恢复。"
echo
echo "备份目录（如有需要可手动恢复）：/sdcard/SystemHelper_backup/"
