#!/system/bin/sh
# 通过 Magisk/KernelSU/APatch 模块在系统层移除 SystemHelper
# 原理：在模块目录放一个与系统 APK 目录同名的 .replace，开机时整个目录被替换为空
#
# 用法：
#   adb push scripts/remove_magisk.sh /data/local/tmp/
#   adb shell su -c 'sh /data/local/tmp/remove_magisk.sh'          # 预演
#   adb shell su -c 'sh /data/local/tmp/remove_magisk.sh --apply'  # 执行
#
# 回滚：scripts/rollback.sh

PKG=com.mobiletools.systemhelper
MOD=/data/adb/modules/systemhelper_remove

APPLY=0
case "${1:-}" in
  --apply) APPLY=1 ;;
  -h|--help)
    echo "用法: sh remove_magisk.sh [--apply]"
    exit 0
    ;;
  "") ;;
  *)
    echo "未知参数: $1"
    exit 2
    ;;
esac

echo "=========================================="
echo " SystemHelper 系统级移除"
echo " 模式: $([ "$APPLY" = "1" ] && echo '执行(--apply)' || echo '预演(只打印)')"
echo "=========================================="

if [ "$APPLY" = "1" ] && [ "$(id -u 2>/dev/null)" != "0" ]; then
  echo "错误: --apply 需要 root，请用 su 运行。"
  exit 1
fi

if [ ! -d /data/adb/modules ]; then
  echo "错误: 未找到 /data/adb/modules（需要 Magisk / KernelSU / APatch）。"
  exit 1
fi

APK=$(pm path "$PKG" 2>/dev/null | head -n1 | sed 's/^package://')
echo
echo "[1] 当前生效 APK: ${APK:-未安装}"

SYS_DIR=""
if [ -n "$APK" ]; then
  case "$APK" in
    /system/*|/product/*|/system_ext/*|/vendor/*|/odm/*|/my_*|/preload/*|/oem/*)
      SYS_DIR=$(dirname "$APK")
      ;;
  esac
fi

# 如果当前生效的是 /data/app 的更新版，去找系统分区里的原始副本
if [ -z "$SYS_DIR" ] || [ ! -d "$SYS_DIR" ]; then
  echo "[2] 当前不是系统分区路径，搜索系统分区原始副本..."
  CAND=$(find \
    /system/priv-app /system/app \
    /product/priv-app /product/app \
    /system_ext/priv-app /system_ext/app \
    /vendor/app /odm/app /my_product /my_heytap /preload \
    -maxdepth 2 -type d -iname '*systemhelper*' 2>/dev/null)

  COUNT=$(printf '%s\n' "$CAND" | sed '/^$/d' | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 1 ]; then
    echo "找到多个候选目录，为避免误删，请手动选择："
    printf '%s\n' "$CAND"
    exit 1
  fi
  if [ "$COUNT" = "1" ]; then
    SYS_DIR=$CAND
  else
    FILE=$(find \
      /system/priv-app /system/app \
      /product/priv-app /product/app \
      /system_ext/priv-app /system_ext/app \
      /vendor/app /odm/app /my_product /my_heytap /preload \
      -maxdepth 3 -type f -iname '*systemhelper*.apk' 2>/dev/null | head -n1)
    [ -n "$FILE" ] && SYS_DIR=$(dirname "$FILE")
  fi
fi

if [ -z "$SYS_DIR" ] || [ ! -d "$SYS_DIR" ]; then
  echo
  echo "未找到系统分区副本。"
  if [ -n "$APK" ]; then
    echo "它看起来只是 /data/app 后装应用，直接卸载即可："
    echo "  pm clear $PKG"
    echo "  pm uninstall --user 0 $PKG"
    if [ "$APPLY" = "1" ]; then
      pm clear "$PKG" >/dev/null 2>&1
      pm uninstall --user 0 "$PKG" || pm disable-user --user 0 "$PKG"
      echo "已执行卸载。"
    fi
  else
    echo "应用未安装，无需处理。"
  fi
  exit 0
fi

echo
echo "[3] 系统目录: $SYS_DIR"
ls -la "$SYS_DIR"

# 安全保护：如果 APK 直接放在 /system/app 等分区根目录（不是独立子目录），
# 不能对整个分区目录做 .replace，否则会误删所有系统应用。
BASE=$(basename "$SYS_DIR")
case "$BASE" in
  app|priv-app|system|product|system_ext|vendor|odm|preload|oem|my_product|my_heytap)
    echo
    echo "错误: APK 似乎是独立文件，直接位于 $SYS_DIR。"
    echo "用 .replace 替换整个目录会误删该分区其他应用，已中止。"
    echo "请改用 TWRP 删除该 APK 文件，或手动制作模块。"
    exit 1
    ;;
esac

if ! ls "$SYS_DIR"/*.apk >/dev/null 2>&1; then
  echo
  echo "错误: $SYS_DIR 下没有找到 .apk，已中止（避免误删）。"
  exit 1
fi

REL=${SYS_DIR#/}
echo
echo "[4] 将创建模块: $MOD"
echo "    模块路径: $MOD/$REL/.replace"
echo "    作用: 开机时把 $SYS_DIR 替换为空目录"

if [ "$APPLY" != "1" ]; then
  echo
  echo "预演结束，未做任何修改。"
  echo "确认无误后执行："
  echo "  sh $0 --apply"
  exit 0
fi

BK="/sdcard/SystemHelper_backup/$(date +%Y%m%d_%H%M%S)"
echo
echo "[5] 备份到 $BK"
mkdir -p "$BK" || { echo "备份目录创建失败，已中止。"; exit 1; }
cp -r "$SYS_DIR" "$BK/" || { echo "备份失败，已中止。"; exit 1; }
echo "备份完成: $BK/$(basename "$SYS_DIR")"

echo
echo "[6] 写入 Magisk 模块"
rm -rf "$MOD"
mkdir -p "$MOD/$REL" || exit 1
touch "$MOD/$REL/.replace"
cat > "$MOD/module.prop" <<EOF
id=systemhelper_remove
name=Remove SystemHelper
version=1.0
versionCode=1
author=local
description=Systemless removal of $PKG
EOF
chmod 644 "$MOD/module.prop" 2>/dev/null || true
echo "模块写入完成。"

echo
echo "[7] 卸载当前用户 + 清数据"
pm clear "$PKG" >/dev/null 2>&1
if pm uninstall --user 0 "$PKG" >/dev/null 2>&1; then
  echo "pm uninstall --user 0 成功。"
else
  echo "pm uninstall 失败，尝试 disable-user..."
  pm disable-user --user 0 "$PKG" >/dev/null 2>&1 \
    && echo "pm disable-user 成功。" \
    || echo "disable-user 也失败，请检查输出。"
fi

echo
echo "=========================================="
echo " 完成。请重启设备，使模块生效。"
echo " 重启后验证："
echo "   pm path $PKG"
echo "   pm list packages | grep -i systemhelper"
echo
echo " 如无法开机：进 TWRP 删除 $MOD"
echo " 或执行 rollback.sh"
echo "=========================================="
