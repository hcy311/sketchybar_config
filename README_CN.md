# SketchyBar 配置

这是一个基于 Lua API 的个人 SketchyBar 配置，面向 macOS 日常使用，并尽量保证其他机器也能复现安装。

English documentation: [README.md](README.md)

## 功能

- 使用 Lua 编写的模块化 SketchyBar 配置，主要 item 位于 `items/`。
- 默认使用 Homebrew 的 SketchyBar binary，并提供本地签名和 Accessibility TCC 修复脚本。
- 保留可选的 `SketchyBar.app` wrapper 方案，用于需要 app bundle 身份时兜底。
- 启动时根据当前壁纸生成类似 Material You 的 bar 背景色，并更偏向壁纸顶部区域里更美观的柔和 surface 色。
- 支持系统浅色/深色模式。浅色模式下文字和图标自动切换为黑色系，深色模式下使用浅色系。
- Mission Control 桌面空间显示，并展示每个空间里的应用图标。
- 当前前台应用显示，点击可在菜单栏和桌面空间显示之间切换。
- Apple 菜单和 macOS 菜单栏项目集成。
- 日期和时间组件。
- 电池组件，点击可显示剩余时间。
- 音量组件，支持弹出输出设备列表和滚轮调节音量。
- Wi-Fi / 网络速率组件，点击可查看网络详情，并支持点击复制字段。
- Wi-Fi popup 内置通用代理检测，支持 Clash Verge、Quantumult X、Shadowrocket 和 Loon。
- CPU 图表组件，使用本地 helper 事件提供器。
- 媒体组件，支持 Spotify / Music 的封面、歌曲信息和控制按钮。
- 微信、QQ、WhatsApp、Telegram 未读数显示，应用未运行时自动隐藏。
- 纯图标咖啡因组件，点击切换 `caffeinate -dimsu` 防睡眠状态。
- 额外提供可独立使用的 `Loon` 保活目录，适合在 macOS 上依赖 `Loon 2.app` 的场景。

## 依赖

- macOS
- 通过 Homebrew 安装的 [SketchyBar](https://github.com/FelixKratz/SketchyBar)
- Lua 5.5 和 [SbarLua](https://github.com/FelixKratz/SbarLua) 的 SketchyBar Lua bridge
- Xcode Command Line Tools，用于编译 helper 和 Swift 壁纸取色工具
- Hack Nerd Font，用于微信和 QQ 图标
- `sketchybar-app-font`，用于 spaces 和前台应用 item 的应用图标

## 重要警告

当前配置使用 `scripts/sign_and_grant_accessibility.sh` 修复 SketchyBar 在 macOS 辅助功能权限中无法正常授权的问题。

运行前请一定看完：

- 这个脚本会直接修改系统级 TCC 数据库：`/Library/Application Support/com.apple.TCC/TCC.db`。
- 它会要求管理员密码，并手动写入 Accessibility allow 记录。
- 它会用本地自签名 Code Signing 证书重新签名 Homebrew 安装的 SketchyBar binary。
- 这是针对 macOS TCC / 签名身份不匹配问题的 workaround，不是 Apple 或 SketchyBar 官方流程。
- Homebrew 升级会替换 SketchyBar binary，签名和 TCC code requirement 可能再次失效。每次升级 SketchyBar 后都要重新运行这个脚本。
- 继续实验前建议备份 TCC 数据库。如果 macOS 权限表现异常，注销/重新登录或重启通常能刷新 TCC/session 缓存。

## 安装

将仓库 clone 到 SketchyBar 默认配置目录：

```sh
git clone git@github.com:hcy311/sketchybar_config.git ~/.config/sketchybar
cd ~/.config/sketchybar
./scripts/sign_and_grant_accessibility.sh
```

这个脚本会用本地 Code Signing 证书签名 Homebrew 的 SketchyBar binary，把匹配当前签名的 Accessibility 记录写进系统 TCC 数据库，并重启 Homebrew LaunchAgent。

如果你想改用 app wrapper 兜底方案，可以运行：

```sh
./scripts/sync_sketchybar_app.sh
```

然后在 `系统设置` -> `隐私与安全性` -> `辅助功能` 中添加 `~/.config/sketchybar/SketchyBar.app` 并打开开关。

## 升级 SketchyBar

每次通过 Homebrew 升级 SketchyBar 后，binary 会变化，macOS 可能无法再匹配旧的 Accessibility code requirement。升级后重新签名并修复权限：

```sh
brew upgrade sketchybar
cd ~/.config/sketchybar
./scripts/sign_and_grant_accessibility.sh
```

`scripts/sign_and_grant_accessibility.sh` 会做这些事：

- 如果还没有签名证书，就创建一个本地自签名 Code Signing 证书。
- 重新签名当前 Homebrew SketchyBar binary。
- 强制 Homebrew LaunchAgent 启动 `/opt/homebrew/bin/sketchybar`。
- 用 `csreq` 生成当前签名对应的 code requirement。
- 直接向 `/Library/Application Support/com.apple.TCC/TCC.db` 写入 Accessibility allow 记录，覆盖 Homebrew、opt、Cellar 三种路径。
- 重启 `tccd` 和 `homebrew.mxcl.sketchybar`。

旧的 app wrapper 脚本 `scripts/sync_sketchybar_app.sh` 仍然保留。它会构建 `SketchyBar.app`、重新签名、编译 `scripts/wallpaper_color.swift`、安装独立的 `com.hcy.sketchybar` LaunchAgent，并重新加载 SketchyBar。

`SketchyBar.app` 被故意放进 `.gitignore`，因为它包含生成出来的 Homebrew 二进制副本和 ad-hoc 签名。它应该在各自环境里重新生成，而不是提交到仓库。

## 字体

仓库内附带了当前配置需要且可分发的字体：

- [fonts/HackNerdFont-Regular.ttf](fonts/HackNerdFont-Regular.ttf)
- [fonts/sketchybar-app-font.ttf](fonts/sketchybar-app-font.ttf)

安装命令：

```sh
cp fonts/*.ttf ~/Library/Fonts/
```

`SF Pro` 和 `SF Mono` 仍然由配置引用，但它们属于 Apple 字体，不会提交到这个仓库里。

## 代理检测

现在 Wi-Fi 组件同时承担代理状态指示功能。

- 支持：`Clash Verge`、`Quantumult X`、`Shadowrocket`、`Loon`
- popup 里会显示 `Proxy: <app> <status>`
- 当网络本身在线时，Wi-Fi 图标颜色会反映当前代理状态
- 检测采用白名单机制，所以像 `Tailscale`、`AdGuard` 这类非目标代理 VPN 不会被算进去

当前检测优先使用 macOS 的 `scutil --nc list` 网络服务状态，再结合：

- 系统是否存在 `utun`
- 对应代理 app 的 helper / tunnel 进程是否存在

状态含义：

- `on`：白名单代理已连接，存在 `utun`，且对应进程也存在
- `off`：没有处于活动状态的白名单代理连接
- `error`：系统看起来已连上代理 VPN，但对应 helper / tunnel 进程缺失

关于 Loon 的重点说明：

- bar / popup 里显示的是 `Loon`
- 检测同时支持 `Loon.app` 和 `Loon 2.app`
- 目前实现仍然优先兼容 `Loon 2.app`，因为原生 macOS 版 `Loon.app` 对部分用户来说仍不稳定
- 但无论实际命中哪个 bundle，界面显示名统一写成 `Loon`

## Loon 2 保活

仓库里额外提供了独立的 [loon2-watchdog](loon2-watchdog) 目录，给在 macOS 上依赖 `Loon 2.app` 的场景使用。

- 定时检查 `LoonTunnelProvider` 是否仍然存在
- 如果 provider 掉了，就后台重新打开 `Loon 2`
- 它与 SketchyBar 主配置解耦，可以独立启用或移除
- 当前保活脚本针对的是 `Loon 2.app`

## 本地生成文件

以下文件会在安装过程中生成，并被 git 忽略：

- `SketchyBar.app/`
- `helpers/**/bin/`
- `scripts/wallpaper_color`
- `.DS_Store`

## 常用命令

重启真正的 LaunchAgent：

```sh
launchctl kickstart -k gui/$(id -u)/homebrew.mxcl.sketchybar
```

给已经运行的 bar 发送刷新事件：

```sh
sketchybar --trigger forced
```

终端里的 `sketchybar` 通常会指向 `/opt/homebrew/bin/sketchybar`。Homebrew LaunchAgent 也应该指向同一个路径，这样 Accessibility/TCC 看到的 client path 更稳定。

检查终端命令路径：

```sh
which sketchybar
```

检查 LaunchAgent 实际启动目标：

```sh
launchctl print gui/$(id -u)/com.hcy.sketchybar
launchctl print gui/$(id -u)/homebrew.mxcl.sketchybar
```

## 参考来源

- [FelixKratz/SketchyBar](https://github.com/FelixKratz/SketchyBar)：状态栏本体和官方命令/API 文档。
- [FelixKratz/SbarLua](https://github.com/FelixKratz/SbarLua)：SketchyBar Lua bridge，以及本配置主体所参考的 Lua example 结构。
- [AIboy996/dotfiles sketchybar](https://github.com/AIboy996/dotfiles/tree/main/sketchybar)：微信/QQ 未读数 item 的灵感来源。
