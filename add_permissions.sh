#!/bin/bash
# 此脚本在构建阶段将相机和照片库权限添加到自动生成的Info.plist文件中

# 获取Info.plist路径（自动生成的Info.plist通常位于构建目录中）
PLIST_PATH="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

# 检查文件是否存在
if [ ! -f "$PLIST_PATH" ]; then
    echo "错误: Info.plist 文件不存在: $PLIST_PATH"
    exit 1
fi

# 使用PlistBuddy添加相机权限描述
/usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string '允许访问相机以便您拍摄资产照片'" "$PLIST_PATH" || \
/usr/libexec/PlistBuddy -c "Set :NSCameraUsageDescription '允许访问相机以便您拍摄资产照片'" "$PLIST_PATH"

# 使用PlistBuddy添加照片库权限描述
/usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string '允许访问照片库以便您选择资产照片'" "$PLIST_PATH" || \
/usr/libexec/PlistBuddy -c "Set :NSPhotoLibraryUsageDescription '允许访问照片库以便您选择资产照片'" "$PLIST_PATH"

echo "成功添加权限描述到 Info.plist: $PLIST_PATH" 