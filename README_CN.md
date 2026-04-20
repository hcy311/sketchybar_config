# SketchyBar 配置

这是一个基于 Lua API 的个人 SketchyBar 配置，面向 macOS 日常使用，并尽量保证其他机器也能复现安装。

English documentation: [README.md](README.md)

## 功能

- 使用 Lua 编写的模块化 SketchyBar 配置，主要 item 位于 `items/`。
- 自动生成 `SketchyBar.app` wrapper，并通过独立的 `com.hcy.sketchybar` LaunchAgent 启动，解决 Homebrew 命令行二进制在 macOS 辅助功能权限里不稳定显示的问题。
- 启动时根据当前壁纸生成类似 Material You 的 bar 背景色，并更偏向壁纸顶部区域里更美观的柔和 surface 色。
- 支持系统浅色/深色模式。浅色模式下文字和图标自动切换为黑色系，深色模式下使用浅色系。
- Mission Control 桌面空间显示，并展示每个空间里的应用图标。
- 当前前台应用显示，点击可在菜单栏和桌面空间显示之间切换。
- Apple 菜单和 macOS 菜单栏项目集成。
- 日期和时间组件。
- 电池组件，点击可显示剩余时间。
- 音量组件，支持弹出输出设备列表和滚轮调节音量。
- Wi-Fi / 网络速率组件，点击可查看网络详情，并支持点击复制字段。
- CPU 图表组件，使用本地 helper 事件提供器。
- 媒体组件，支持 Spotify / Music 的封面、歌曲信息和控制按钮。
- 微信和 QQ 未读数显示，应用未运行时自动隐藏。
- 纯图标咖啡因组件，点击切换 `caffeinate -dimsu` 防睡眠状态。

## 依赖

- macOS
- 通过 Homebrew 安装的 [SketchyBar](https://github.com/FelixKratz/SketchyBar)
- Lua 5.5 和 [SbarLua](https://github.com/FelixKratz/SbarLua) 的 SketchyBar Lua bridge
- Xcode Command Line Tools，用于编译 helper 和 Swift 壁纸取色工具
- Hack Nerd Font，用于微信和 QQ 图标

## 安装

将仓库 clone 到 SketchyBar 默认配置目录：

```sh
git clone git@github.com:hcy311/sketchybar_config.git ~/.config/sketchybar
cd ~/.config/sketchybar
./scripts/sync_sketchybar_app.sh
```

然后打开 `系统设置` -> `隐私与安全性` -> `辅助功能`，添加：

```text
~/.config/sketchybar/SketchyBar.app
```

并打开 `SketchyBar.app` 的权限开关。

## 升级 SketchyBar

每次通过 Homebrew 升级 SketchyBar 后，重新生成本地 app wrapper：

```sh
brew upgrade sketchybar
cd ~/.config/sketchybar
./scripts/sync_sketchybar_app.sh
```

这个脚本会构建 `SketchyBar.app`、重新签名、编译 `scripts/wallpaper_color.swift`、停止 Homebrew 管理的 SketchyBar service，安装独立的 `com.hcy.sketchybar` LaunchAgent，并重新加载 SketchyBar。

使用独立 LaunchAgent 是为了避免 Homebrew 升级或 `brew services` 重写 plist 后，又偷偷切回原始 Homebrew binary。如果之后手动运行了 `brew services start sketchybar`，再运行一次 `./scripts/sync_sketchybar_app.sh` 即可重新接管。

`SketchyBar.app` 被故意放进 `.gitignore`，因为它包含本机 Homebrew 二进制副本和本地 ad-hoc 签名。它应该在每台机器上重新生成，而不是提交到仓库。

## 本地生成文件

以下文件会在本机生成，并被 git 忽略：

- `SketchyBar.app/`
- `helpers/**/bin/`
- `scripts/wallpaper_color`
- `.DS_Store`

## 常用命令

重启真正的 LaunchAgent：

```sh
launchctl kickstart -k gui/$(id -u)/com.hcy.sketchybar
```

给已经运行的 bar 发送刷新事件：

```sh
sketchybar --trigger forced
```

终端里的 `sketchybar` 通常会指向 `/opt/homebrew/bin/sketchybar`。它适合用来给正在运行的 bar 发命令，但不应该当成服务启动器。真正持久运行的服务要用 `launchctl` 检查，并且应该指向 `SketchyBar.app`。

检查终端命令路径：

```sh
which sketchybar
```

检查 LaunchAgent 实际启动目标：

```sh
launchctl print gui/$(id -u)/com.hcy.sketchybar
```

## 参考来源

- [FelixKratz/SketchyBar](https://github.com/FelixKratz/SketchyBar)：状态栏本体和官方命令/API 文档。
- [FelixKratz/SbarLua](https://github.com/FelixKratz/SbarLua)：SketchyBar Lua bridge，以及本配置主体所参考的 Lua example 结构。
- [AIboy996/dotfiles sketchybar](https://github.com/AIboy996/dotfiles/tree/main/sketchybar)：微信/QQ 未读数 item 的灵感来源。
