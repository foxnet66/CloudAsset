# 构建脚本配置说明

为了确保应用程序拥有必要的相机和照片库访问权限，需要配置构建脚本。请按照以下步骤操作：

## 步骤 1: 确保构建脚本可执行

请确保 `add_permissions.sh` 脚本文件具有执行权限：

```bash
chmod +x add_permissions.sh
```

## 步骤 2: 在 Xcode 中添加构建脚本阶段

1. 在 Xcode 中打开项目
2. 选择 CloudAsset 主项目
3. 选择 CloudAsset 目标
4. 点击 "Build Phases" 选项卡
5. 点击左上角的 "+" 按钮
6. 选择 "New Run Script Phase"
7. 将构建阶段拖动到 "Copy Bundle Resources" 阶段的下方
8. 在脚本框中输入以下内容：

```bash
"${PROJECT_DIR}/add_permissions.sh"
```

9. （可选）点击三角形展开 "Input Files" 和 "Output Files" 部分：
   - 在 "Input Files" 中添加: `$(PRODUCT_NAME)/Info.plist`
   - 在 "Output Files" 中添加: `$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)`

10. 点击脚本标题（默认为 "Run Script"），重命名为 "Add Permissions to Info.plist"

## 步骤 3: 清理并重新构建项目

为了确保更改生效，请执行以下操作：

1. 选择 Xcode 菜单中的 "Product" > "Clean Build Folder"
2. 然后选择 "Product" > "Build"

## 可能的替代解决方案

如果构建脚本无法工作，可以直接在 Xcode 的项目设置中添加这些权限：

1. 在 Xcode 中选择 CloudAsset 项目
2. 选择 CloudAsset 目标
3. 点击 "Info" 选项卡
4. 右键点击并选择 "Add Row"
5. 添加 `Privacy - Camera Usage Description` 并设置值为 "允许访问相机以便您拍摄资产照片"
6. 添加 `Privacy - Photo Library Usage Description` 并设置值为 "允许访问照片库以便您选择资产照片"

保存并重新构建项目。 