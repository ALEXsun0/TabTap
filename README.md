# TabTap

TabTap 是一个面向单手浏览场景的轻量 macOS 菜单栏工具。只用触控板或鼠标
浏览网页时，直接双击 Google Chrome 原生标签页即可关闭：不需要使用快捷键，
也不需要把指针准确移到狭小的关闭按钮上。

TabTap 不会向 Chrome 注入代码、修改浏览器应用包或读取网页内容。

## 使用方式

1. 将 TabTap 拖入“应用程序”文件夹并启动。
2. 按向导顺序授予“辅助功能”和“输入监控”权限。
3. 输入监控授权后重新启动 TabTap。
4. 双击 Chrome 标签标题区域关闭标签页。

## 系统要求

- macOS 13 或更高版本
- Google Chrome
- 为 TabTap 授予“辅助功能”和“输入监控”权限

首次启动只会显示授权向导，不会主动弹出系统权限请求。先点击并授予“辅助功能”，
再申请“输入监控”；输入监控授权后使用向导中的“重新启动”按钮重启 TabTap。
授权完成后让 TabTap 保持在菜单栏运行即可。
只有被 macOS 辅助功能识别为 Chrome 标签页的双击才会被处理。

TabTap 首次启动会显示“权限与状态”窗口，依次检测辅助功能、输入监控和监听
状态。完成后关闭窗口不会退出应用，TabTap 会保留菜单栏图标并在后台运行。
需要重新检查权限时，可从菜单栏选择“权限与状态...”。

正式签名的发布版会在用户点击申请后请求 macOS 自动登记输入监控权限。ad-hoc
签名的本地测试版没有稳定代码身份，部分 macOS 版本仍会要求通过列表底部的
“+”选择 `/Applications/TabTap.app`。

## 构建

```sh
swift test
./script/build_and_run.sh --build-only
```

应用包生成在 `dist/TabTap.app`。

要在 Intel runner 上为 Apple Silicon 交叉构建：

```sh
TARGET_ARCH=arm64 ./script/build_and_run.sh --build-only
```

## 制作 DMG

```sh
./script/package_dmg.sh
```

安装镜像生成在 `dist/TabTap-<版本>-macOS-arm64.dmg`，其中包含 TabTap 和
“应用程序”文件夹的快捷方式。

默认构建使用 ad-hoc 签名，适合本机安装和测试。用于互联网分发时，需要在
钥匙串中安装 Apple Developer ID Application 证书，再指定签名身份：

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ./script/package_dmg.sh
```

正式公开发布还需要将生成的 DMG 提交 Apple 公证并装订公证票据。

## GitHub Actions 测试包

每次推送到 `main` 或手动运行 `Build macOS DMG` 工作流时，CI 会执行测试并
生成 ad-hoc 签名的 Apple Silicon DMG。构建完成后，可在对应 Actions 运行页
底部下载 `TabTap-macOS-arm64` artifact。该测试包不是正式签名发行版，更新后
可能需要重新授权。

## 隐私

TabTap 不包含网络请求、遥测、分析或自动更新服务。鼠标事件仅在本地判断，
处理后立即丢弃。

## 许可证

MIT
