> **基于 [vibe-notch](https://github.com/farouqaldori/vibe-notch)（Apache-2.0）二次开发** · 原作者 [farouqaldori](https://github.com/farouqaldori)

<div align="center">
  <img src="CcIslandCn/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Logo" width="100" height="100">
  <h3 align="center">cc-island-cn</h3>
  <p align="center">
    一款 macOS 菜单栏应用，为 Claude Code CLI 会话带来灵动岛式的实时通知。
    <br />
    <br />
    <a href="https://github.com/OrangeCold/cc-island-cn/releases/latest" target="_blank" rel="noopener noreferrer">
      <img src="https://img.shields.io/github/v/release/OrangeCold/cc-island-cn?style=rounded&color=white&labelColor=000000&label=release" alt="Release Version" />
    </a>
    <a href="https://github.com/OrangeCold/cc-island-cn/releases" target="_blank" rel="noopener noreferrer">
      <img alt="GitHub Downloads" src="https://img.shields.io/github/downloads/OrangeCold/cc-island-cn/total?style=rounded&color=white&labelColor=000000">
    </a>
  </p>
</div>

## 功能特性

- **灵动岛界面** —— 从 MacBook 刘海处展开的动画悬浮层
- **实时会话监控** —— 同时追踪多个 Claude Code 会话的运行状态
- **权限审批** —— 直接在灵动岛上批准或拒绝工具执行请求
- **聊天历史** —— 以 Markdown 渲染查看完整的对话历史
- **自动配置** —— 首次启动时自动安装 hooks

## 环境要求

- macOS 15.6+
- Claude Code CLI

## 安装

下载最新 [Release](https://github.com/OrangeCold/cc-island-cn/releases/latest)，或从源码构建：

```bash
xcodebuild -scheme CcIslandCn -configuration Release build
```

## 工作原理

cc-island-cn 会在 `~/.claude/hooks/` 安装 hooks，通过 Unix socket 传递会话状态。应用监听这些事件，并在灵动岛悬浮层中展示。

当 Claude 需要执行某个工具时，灵动岛会展开批准/拒绝按钮——无需切换回终端。

## 数据统计

cc-island-cn **不收集任何用户数据**。原项目 vibe-notch 内置的 Mixpanel 埋点已在二次开发时彻底移除。

## 协议

Apache 2.0，详见 [LICENSE.md](LICENSE.md)。
