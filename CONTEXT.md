# cc-island-cn 领域术语

灵动岛式 macOS 菜单栏应用，为 Claude Code CLI 会话提供实时通知与交互。本文件是领域术语表（glossary），仅定义业务概念，不含实现细节。

## 语言

**自动展开（Auto-expand）**：
灵动岛在检测到会话「需要注意」时，主动从收起态展开为打开态。触发原因是会话状态变化，区别于用户主动的点击展开与悬停展开。
_Avoid_: 自动弹出、通知展开

**需要注意（Needs attention）**：
会话进入需要用户关注的阶段，含两种：任务完成等待输入、工具权限请求待批。两者都使会话进入 pending 列表。
_Avoid_: pending、active

**待授权（Pending approval）**：
Claude Code 请求执行某个工具的权限、等待用户批准的会话状态。不批准则会话阻塞。
_Avoid_: 权限请求、permission request、waiting for approval

**收起态（Closed state）**：
灵动岛贴合刘海的窄条形态，仅两侧露出有限区域展示图标与状态符号。
_Avoid_: 关闭态、collapsed

**工具摘要（Tool summary）**：
收起态中间区域显示的内容之一：正在执行的工具名与关键参数（如 `Bash · npm test`），跨会话取最近活跃者。与会话进度互斥，由用户配置二选一。
_Avoid_: 命令、currentTool

**会话进度（Session progress）**：
收起态中间区域显示的内容之一：已完成会话数 / 存活会话总数（如 `1/3`）。「已完成」指会话完成任务等待输入；会话结束后即从统计中剔除，不做已结束计数。仅当至少一个会话运行中时显示，全部停下后短暂停留即淡出。
_Avoid_: 会话数、完成比例、进度条

**状态符号（Status glyph）**：
收起态右侧的三态图标，让用户不展开即可识别会话阶段：处理中显示转圈、已完成显示对勾、待授权显示手指点击。
_Avoid_: 右侧图标、indicator
