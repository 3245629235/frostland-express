#!/usr/bin/env bash
# Frostland Express Android 模拟器冒烟（Day 7）
# 用法：bash tools/android_smoke.sh
set -e
SDK="$LOCALAPPDATA/Android/Sdk"
AVDNAME="frostland_smoke"
APK="C:/Users/Mr Ray/Desktop/frostland-express-clean/dist/FrostlandExpress.apk"

echo "[1/5] 创建 AVD: $AVDNAME"
echo no | "$SDK/cmdline-tools/latest/bin/avdmanager.bat" create avd \
  -n "$AVDNAME" -k "system-images;android-35;google_apis;x86_64" -d "pixel_5" --force 2>&1 | tail -2

echo "[2/5] 启动模拟器（后台，无窗口加速模式）"
"$SDK/emulator/emulator.exe" -avd "$AVDNAME" -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect > "$LOCALAPPDATA/Temp/emulator_smoke.log" 2>&1 &
EMU_PID=$!

echo "[3/5] 等待系统启动（最多 240s）"
"$SDK/platform-tools/adb.exe" wait-for-device
for i in $(seq 1 48); do
  BOOT=$("$SDK/platform-tools/adb.exe" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  if [ "$BOOT" = "1" ]; then echo "  系统启动完成（${i}x5s）"; break; fi
  sleep 5
done

echo "[4/5] 安装 APK"
"$SDK/platform-tools/adb.exe" install -r "$APK" 2>&1 | tail -2

echo "[5/5] 启动游戏并截图"
"$SDK/platform-tools/adb.exe" shell am start -n com.frostland.express/com.godot.game.GodotApp 2>&1 | tail -1
sleep 12
"$SDK/platform-tools/adb.exe" exec-out screencap -p > "C:/Users/Mr Ray/Desktop/frostland_emulator_title.png"
echo "截图: C:/Users/Mr Ray/Desktop/frostland_emulator_title.png"
"$SDK/platform-tools/adb.exe" shell "dumpsys activity activities | grep -E 'mResumedActivity|topResumedActivity'" 2>/dev/null | head -2
echo "冒烟完成"
