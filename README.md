# Outfitter（乌龟服定制版 · 修改构建）

> **非官方修改版。** 本仓库是 **Sunelegy** 的乌龟服定制版 Outfitter 的再修改构建，
> 面向 **Turtle WoW / WoW 1.12（Interface 11200）** 客户端。
> 原版 Outfitter 及其定制版的版权归各自作者所有，本仓库不主张任何版权、不附加任何新许可。
>
> 本仓库地址：**https://github.com/tian880212/Outfitter**

自动一键换装。按预设场景（坐骑、战斗中、隐身、变形、采集、银色黎明、休息等）自动切换整套装备，
并提供一套常驻的**快捷换装面板（QuickSwap）**用来手动或按冷却/队列换饰品、武器、护甲。

---

## 安装

1. 把整个 `Outfitter` 文件夹放进 `Interface\AddOns\`（文件夹名必须叫 `Outfitter`）
2. **不需要安装公共库** —— 本版已内嵌它用到的三个库：
   ```
   Libs\AceLibrary\AceLibrary.lua
   Libs\AceOO-2.0\AceOO-2.0.lua
   Libs\AceEvent-2.0\AceEvent-2.0.lua
   ```
   `Outfitter.toc` 里的 `OptionalDeps: TankPoints, Ace2` 只是**可选**增强，缺了照常运行
3. 可选：装了 **pfUI** 会自动套用 pfUI 风格皮肤（见下）

## 命令

| 命令 | 作用 |
| --- | --- |
| `/outfitter` | 打开主设置窗口 |
| `/qswap`、`/oswap`、`/快速换装` | 快捷换装面板相关（同一入口的三个别名） |

## 本版相对 Sunelegy 定制版的改动

### 1. 快捷换装面板（QuickSwap，主窗口第 4 个「快捷换装」标签）

参考 GearMenu / TrinketMenu 的交互模式重做，主要能力：

- **部位勾选**：面板只显示勾选的部位；`精简模式` 只保留装备图标
- **同类装备弹出网格**：悬停按钮弹出可换的同部位装备，列数按数量自适应（2/3/4/5 列），
  方向可设为向上/向下，鼠标离开按钮与弹框 0.75s 后自动收起
- **冷却与走秒**：按钮转盘显示冷却；可选数字倒计时（`12 s` / `5 m` / `1 h`，GCD 不闪现）；
  迷你提示模式下冷却剩余每 1s 刷新
- **战斗中排队**：战斗中点击部位 = 按物品名排队（多槽队列 + 栏位角标），
  脱战 / 复活 / 跑尸后自动换上
- **按物品排队延迟**（`QueueDelays`，参考 TrinketMenu 的 Swap Delay）：
  当前饰品刚触发、经过时间不足设定秒数且冷却仍 >30s 时**不换下**，让 buff 跑满
- **优先物品**（`QueuePriorities`）：标记为优先的物品一就绪立即换上使用，
  不受「就绪保持」与延迟保护约束；当前装备正好是该优先物品时保持，避免两件就绪饰品每秒互跳
- **暂停部位**（`PausedSlots`，Alt+右键，角标变红）与**屏蔽物品**（`HiddenItems`，Alt+右键，图标灰化）
- **排队设置窗**（右键菜单「自动排队设置…」/ 弹出列表 Ctrl+左键）：
  部位下拉 → 上移/下移排序 → 物品列表 → 延迟秒数 → 优先/暂停勾选框；ESC 关闭，
  Alt 增删队列时若窗口开着会自动同步
- **饰品模式 / 弹出列表常显**等右键菜单开关
- **拖动区悬停提示**：标题栏与栏位条空白处悬停显示「左键拖动移动 / 滚轮缩放 / 右键菜单」，
  锁定态换成「已锁定」文案
- **默认落点**：锚在 **BCS 属性悬浮窗正上方**（旧的右下角默认落点会和 pfUI 目标头像重叠）；
  没装 BCS 时退回原右下角固定位置，首次重锚后即与 BCS 解耦、写入存档
- 滚轮缩放 0.5–2.0（步进 5%，左下角不动）；位置、缩放、锁定状态按角色存 `gOutfitter_Settings`

### 2. pfUI 皮肤完全外置

皮肤代码整体搬到独立的 `pfui-skin.lua`，**`Outfitter.lua` 里不再有任何 pfUI 相关代码**——
不装 pfUI 时等于零开销，也不会因为 pfUI 缺失而报错。就绪检查走 `pfUI.api` + `pfUI.env.C`，
在 `ADDON_LOADED("Outfitter")`、`PLAYER_LOGIN` 以及**此后任意 `ADDON_LOADED`** 上重试
（新角色首登时序不稳，只检查一次会整场没有皮肤，残留经典外观）。

### 3. 双手 / 副手互斥处理

拖拽路径（`PickupContainerItem` + `PickupInventoryItem`）**不会**像右键路径（`UseContainerItem`）
那样由引擎自动腾手，所以本版显式处理：

- 装副手而主手是双手武器 → 先卸主手
- 装双手武器而副手有货 → 先卸副手
- 副手唯一槽物品（`IsOffHandOnlyItem`）改走 `UseContainerItem` 让引擎处理

### 4. WoW 1.12 客户端适配

原版按 TBC/后续版本写的部分在本客户端会静默失效或报错，已逐项修掉：

- **layer 0 的 BACKGROUND 纹理** `GetRegions()` 不返回、`StripTextures` 清不掉，
  残留纹理会吞掉点击 → 按控件名显式 `SetTexture(nil)`
- **`SetDesaturated(1)` 在 pfUI 皮肤下会让贴图整个消失** → 灰化一律改用 `SetVertexColor`
- **`Button` 没有 `SetNormalFontObject` / `SetHighlightFontObject` / `SetDisabledFontObject`**
  （实测 nil 报错）→ 文字改用自建 FontString
- `GetItemInfo` 返回的字段布局缺 `reqLevel`、整体前移 → 不硬编索引，按 `^INVTYPE_` / `^Interface\\` 扫描
- Lua 5.0：无 `%`（用 `math.mod`）、无 `#`（用 `table.getn`）、`SetScript` 回调不传 `self`

### 5. 存档

- `gOutfitter_Settings`（`SavedVariablesPerCharacter`，按角色）：套装、场景规则、QuickSwap 的位置/缩放/队列/延迟/优先/暂停/屏蔽
- 新增的设置字段一律 **SaveSettings 与 LoadSettings 成对**（历史上 `QueueDelays` 曾只写不读，设好重登即丢）

---

## 已知限制

- 排队设置窗的物品列表超过 10 行不做滚动（未实现）
- 位置与缩放以角色为单位保存；换分辨率后若面板跑到屏幕外，用 `/qswap` 重置或在设置页重新放置
- 本仓库不含 `Textures\` 以外的美术资源，贴图版权同样归原作者

## 与其它插件的关系

- **pfUI**：可选。装了自动套皮肤（见 §2）
- **BCS**：可选。装了则面板默认落在其属性悬浮窗上方
- **TankPoints**：可选（`OptionalDeps`），影响少量装备评估提示
- 本插件**不依赖** `!Libs`，与 `Interface\AddOns\` 下的公共库互不影响
