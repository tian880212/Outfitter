--==========================================================================
-- Outfitter QuickSwap（快速换装栏，参考 GearMenu / TrinketMenu 模式）
--
-- 交互（参考 TrinketMenu）：
--   · 配置在 Outfitter 主窗口第 4 个标签「快捷换装」页：
--       启用快捷换装面板 / 精简模式（只显示装备）/ 同类装备向上弹出 / 部位勾选
--   · 小面板只显示已勾选部位的已穿戴装备图标与冷却（每 0.5s 刷新走秒）
--   · 悬停按钮 = 显示 tooltip 并在按钮旁弹出同类装备网格（方向可设置）
--   · 点击弹出网格中的装备 = 换装（原装备自动回背包）
--   · 左键点击按钮 = 使用该装备（UseInventoryItem，饰品等主动物品生效）
--   · 右键点击按钮 = 也可弹出/收起同类装备列表
--   · 鼠标同时离开按钮和弹出框 0.75s 后自动收起
--   · 迷你提示（TrinketMenu TinyTooltips 同款）：悬停提示精简为 名字/充能/冷却剩余，
--     有冷却时每 1s 自动刷新走秒，战斗中排队的部位附加「已排队」行（可在设置页开关）
--   · 冷却计时（TrinketMenu CooldownCount 同款，默认关）：按钮上显示 "12 s"/"5 m"/"1 h"
--     倒计时，GCD(<3s 且无文字)不闪现；转盘不受开关影响照常显示
--   · 战斗中点护甲部位 = 按物品名排队（多槽队列 + 栏位角标），脱战/复活/跑尸后自动换
--   · Shift+点击 = 把物品链接插入聊天输入框
--   · 弹出网格列数按数量自适应（2/3/4/5 列，TrinketMenu.BuildMenu 同款）
--
-- 命令：/qswap /oswap /快速换装  开关面板
-- 保存：gOutfitter_Settings.QuickSwap（角色级：位置/显隐/勾选部位）
--
-- 兼容本客户端（Turtle/1.12）：GetItemInfo 用 pcall 包裹并按返回值特征
-- 扫描 equipLoc/quality，失败回退隐藏 tooltip 扫描。
-- Lua 5.0：table.getn()，SetScript 回调内用 this（不传 self）。
--==========================================================================

--------------------------------------------------------------------------
-- 聊天命令（最先注册：即使后续初始化出错，命令也保持可用）
--------------------------------------------------------------------------

SLASH_OUTFITTERQSWAP1 = "/qswap";
SLASH_OUTFITTERQSWAP2 = "/oswap";
SLASH_OUTFITTERQSWAP3 = "/快速换装";

SlashCmdList["OUTFITTERQSWAP"] = function()
    OutfitterQuickSwap_Toggle();
end

gOutfitterQuickSwap_EnabledSlots = {
    -- 默认勾选两个饰品（TrinketMenu 定位：快捷换装栏首要用途是饰品快切），
    -- 首个饰品自动弹出时栏位条直接显示饰品格；其余部位由用户在「快捷换装」页自选
    Trinket0Slot = true,
    Trinket1Slot = true,
};

-- 面板级设置（随角色保存）
gOutfitterQuickSwap_Settings = {
    Enabled  = true,   -- 总开关：显示快捷换装面板
    AutoShown = true,  -- 首个饰品自动弹出标记（LoadSettings 按存档覆盖，见下）
    Compact  = true,   -- 精简模式：只显示装备（无标题栏/背景/提示），默认开启
    PopupUp  = true,   -- 同类装备向上弹出（TrinketMenu 默认向上）
    TinyTooltip = true, -- 迷你提示：悬停提示只显示 名字/充能/冷却剩余（TrinketMenu TinyTooltips 同款）
    CooldownCount = false, -- 冷却计时：按钮上显示剩余冷却时间文字（TrinketMenu CooldownCount，默认关）
    Scale = 1,         -- 面板缩放（0.5-2.0，滚轮在栏位条上滚动调节）
    Queues = {},       -- 自动排队（TrinketMenuQueue 模式）：[部位名] = {物品名有序列表}，非空即启用
    QueueDelays = {},  -- 每物品排队延迟（TrinketMenu「延迟替换」/ Stats[id].delay 同款）：[物品名] = 秒数。
                       -- 物品触发后经过时间 < 延迟 且冷却剩余 >30s 时，自动排队不换下它（保护 buff 跑满）
    QueuePriorities = {}, -- 优先物品（TrinketMenu「优先」同款）：[物品名]=true，一就绪就立即换上使用，
                          -- 不受「当前装备可用即保持」与延迟保护约束（优先 = 尽快用掉它）
    Locked = false,    -- 锁定面板（TrinketMenu Locked）：禁止拖动与滚轮缩放；
                       -- 无 pfUI 时联动边框显隐（TrinketMenu ReflectLock 同款：锁定=边框隐藏更干净，解锁=显示边框方便抓取拖动）
    PopupAlways = false, -- 备选框常显（TrinketMenu KeepOpen「保持列表开启」同款）：
                         -- 悬停/右键弹出的同类装备列表不自动收起，直到再次右键该部位或关栏
    TrinketMode = false, -- 饰品模式（分类双栏）：饰品1/饰品2/圣物栏单独一组，与其余勾选部位
                         -- 分开显示（横排=两行、竖排=两列）；备选列表左键=换入上面饰品(Trinket0Slot)，
                         -- 右键=换入下面饰品(Trinket1Slot)，圣物列表=换入圣物栏（TrinketMenu.MenuTrinket_OnClick 的 slot=13/14 语义）
    Vertical = false,    -- 竖向排列：栏位条按钮纵向排列（false = 横向，默认）
    PausedSlots = {}, -- 按部位暂停自动排队：[部位名]=true（Alt+右键该槽切换，TrinketMenu.SetQueue PAUSE 按菜单粒度同款）
    ShowHotKeys = false, -- 显示按键：装备按钮上显示该部位的绑定键（TrinketMenu ShowHotKeys，默认关）
    HiddenItems = {},    -- 屏蔽装备（弹出列表默认隐藏的物品）：[物品名]=true，平时不在弹出列表显示；
                         -- 按住 Alt 时全部显示并染灰，弹出列表上 Alt+右键该项可恢复
    SlotsConfigured = false, -- 部位勾选是否已被用户配置过（区分"从未配置"与"主动全部取消"：
                             -- 否则全取消后存档 Slots={} 会被判为未配置，重登回弹成默认两饰品）
};

local gQS_PendingRefresh = nil;
local gQS_LastRefresh = 0;
local gQS_LastCooldownCheck = 0;
local gQS_LastQueueCheck = 0;   -- 自动排队检查节流（TrinketMenu.PeriodicQueueCheck 1s 节奏）
local gQS_SlotButtons = {};      -- 栏位按钮池
local gQS_GridButtons = {};      -- 弹出列表按钮池
local gQS_ConfigChecks = {};     -- 「快捷换装」页里的部位复选框池
local gQS_OptionChecks = nil;    -- 「快捷换装」页里的面板开关复选框（Enabled/Compact/PopupUp）
local gQS_PopupSlot = nil;
local gQS_PopupOwner = nil;     -- 弹出框锚定的栏位按钮（悬停弹出用）
local gQS_HideAt = nil;         -- 鼠标同时离开按钮和弹出框后的收起时刻
local gQS_CombatQueue = {};     -- 战斗换装队列，[部位名] = 物品名（TrinketMenu.CombatQueue 模式：
                                --   按名称排队而非坐标，脱战后 FindItem 重新定位，移动了物品也能换）
local gQS_ForceRefreshAt = nil; -- 换装后的兜底刷新时刻（防眩晕等失败后界面不同步）
local gQS_ScaleTextHideAt = nil; -- 缩放百分比提示的消失时刻（滚轮缩放后显示 1s）
local gQS_ScanTooltip = nil;

-- 悬停 tooltip 状态（TrinketMenu.WornTrinketTooltip/TooltipUpdate 模式：
-- 登记后每 1s 重设一次 tooltip，冷却倒数实时走秒，无冷却时自动停止刷新）
local gQS_TooltipOwner = nil;   -- tooltip 锚定的按钮
local gQS_TooltipType = nil;    -- "INVENTORY"（已穿戴）/"BAG"（背包物品）
local gQS_TooltipSlot = nil;    -- 装备位 ID 或背包槽位
local gQS_TooltipBag = nil;     -- 仅 BAG 类型用
local gQS_TooltipNext = 0;      -- 下次刷新时刻

--------------------------------------------------------------------------
-- 数据表
--------------------------------------------------------------------------

-- 可选部位（设置面板顺序 + 短标签）
OutfitterQuickSwap_cSlots = {
    { Slot = "HeadSlot",          Label = HEADSLOT or "头部", Short = "头部" },
    { Slot = "NeckSlot",          Label = NECKSLOT or "颈部", Short = "颈部" },
    { Slot = "ShoulderSlot",      Label = SHOULDERSLOT or "肩部", Short = "肩部" },
    { Slot = "BackSlot",          Label = BACKSLOT or "背部", Short = "背部" },
    { Slot = "ChestSlot",         Label = CHESTSLOT or "胸部", Short = "胸部" },
    { Slot = "WristSlot",         Label = WRISTSLOT or "手腕", Short = "手腕" },
    { Slot = "HandsSlot",         Label = HANDSSLOT or "手", Short = "手" },
    { Slot = "WaistSlot",         Label = WAISTSLOT or "腰部", Short = "腰部" },
    { Slot = "LegsSlot",          Label = LEGSSLOT or "腿部", Short = "腿部" },
    { Slot = "FeetSlot",          Label = FEETSLOT or "脚", Short = "脚部" },
    { Slot = "Finger0Slot",       Label = (FINGERSLOT0 or "手指") .. "1", Short = "戒指1" },
    { Slot = "Finger1Slot",       Label = (FINGERSLOT0 or "手指") .. "2", Short = "戒指2" },
    { Slot = "Trinket0Slot",      Label = (TRINKETSLOT0 or "饰品") .. "1", Short = "饰品1" },
    { Slot = "Trinket1Slot",      Label = (TRINKETSLOT0 or "饰品") .. "2", Short = "饰品2" },
    { Slot = "MainHandSlot",      Label = MAINHANDSLOT or "主手", Short = "主手" },
    { Slot = "SecondaryHandSlot", Label = SECONDARYHANDSLOT or "副手", Short = "副手" },
    { Slot = "RangedSlot",        Label = RANGEDSLOT or "远程", Short = "远程" },
    { Slot = "AmmoSlot",          Label = AMMOSLOT or "弹药", Short = "弹药" },
};

--------------------------------------------------------------------------
-- 按键绑定（TrinketMenu Bindings.xml + ReflectKeyBindings 同款模式）
-- 绑定名 = 前缀 + 部位名大写（如 OUTFITTER_QS_USE_TRINKET0SLOT），
-- 1.12 按键设置界面用 BINDING_HEADER_xxx / BINDING_NAME_xxx 全局做分组与显示名
--------------------------------------------------------------------------

OutfitterQuickSwap_cBindPrefix = "OUTFITTER_QS_USE_";

BINDING_HEADER_OUTFITTER_QUICKSWAP = "快捷换装";
BINDING_NAME_OUTFITTER_QS_TOGGLE = "开关快捷换装栏";

for _, vBindSlot in OutfitterQuickSwap_cSlots do
    setglobal(
        "BINDING_NAME_" .. OutfitterQuickSwap_cBindPrefix .. string.upper(vBindSlot.Slot),
        "使用 " .. vBindSlot.Short
    );
end

-- 部位 → 接受的 equipLoc（INVTYPE_）集合
-- 注：戒指两格共用 INVTYPE_FINGER，饰品两格共用 INVTYPE_TRINKET
OutfitterQuickSwap_cSlotAccept = {
    HeadSlot          = { INVTYPE_HEAD = 1 },
    NeckSlot          = { INVTYPE_NECK = 1 },
    ShoulderSlot      = { INVTYPE_SHOULDER = 1 },
    BackSlot          = { INVTYPE_CLOAK = 1 },
    ChestSlot         = { INVTYPE_CHEST = 1, INVTYPE_ROBE = 1 },
    WristSlot         = { INVTYPE_WRIST = 1 },
    HandsSlot         = { INVTYPE_HAND = 1 },
    WaistSlot         = { INVTYPE_WAIST = 1 },
    LegsSlot          = { INVTYPE_LEGS = 1 },
    FeetSlot          = { INVTYPE_FEET = 1 },
    Finger0Slot       = { INVTYPE_FINGER = 1 },
    Finger1Slot       = { INVTYPE_FINGER = 1 },
    Trinket0Slot      = { INVTYPE_TRINKET = 1 },
    Trinket1Slot      = { INVTYPE_TRINKET = 1 },
    MainHandSlot      = { INVTYPE_2HWEAPON = 1, INVTYPE_WEAPON = 1, INVTYPE_WEAPONMAINHAND = 1 },
    SecondaryHandSlot = { INVTYPE_WEAPON = 1, INVTYPE_WEAPONOFFHAND = 1, INVTYPE_HOLDABLE = 1, INVTYPE_SHIELD = 1 },
    RangedSlot        = { INVTYPE_RANGED = 1, INVTYPE_RANGEDRIGHT = 1, INVTYPE_THROWN = 1, INVTYPE_RELIC = 1 },
    AmmoSlot          = { INVTYPE_AMMO = 1 },
};

-- 战斗中允许更换的部位（1.12 仅武器类可以战斗中换）
OutfitterQuickSwap_cCombatOkSlots = {
    MainHandSlot = 1,
    SecondaryHandSlot = 1,
    RangedSlot = 1,
};

-- zhCN/enUS 装备位标签 → INVTYPE_（GetItemInfo 不可用时 tooltip 扫描回退用）
OutfitterQuickSwap_cCNLabelToInvType = {
    ["头部"] = "INVTYPE_HEAD",
    ["颈部"] = "INVTYPE_NECK",
    ["肩部"] = "INVTYPE_SHOULDER",
    ["背部"] = "INVTYPE_CLOAK",
    ["胸部"] = "INVTYPE_CHEST",
    ["衬衣"] = "INVTYPE_BODY",
    ["战袍"] = "INVTYPE_TABARD",
    ["手腕"] = "INVTYPE_WRIST",
    ["手"] = "INVTYPE_HAND",
    ["腰部"] = "INVTYPE_WAIST",
    ["腿"] = "INVTYPE_LEGS",
    ["脚"] = "INVTYPE_FEET",
    ["手指"] = "INVTYPE_FINGER",
    ["饰品"] = "INVTYPE_TRINKET",
    ["主手"] = "INVTYPE_WEAPONMAINHAND",
    ["副手"] = "INVTYPE_WEAPONOFFHAND",
    ["单手"] = "INVTYPE_WEAPON",
    ["双手"] = "INVTYPE_2HWEAPON",
    ["远程"] = "INVTYPE_RANGED",
    ["投掷"] = "INVTYPE_THROWN",
    ["圣物"] = "INVTYPE_RELIC",
    ["副手物品"] = "INVTYPE_HOLDABLE",
    ["盾牌"] = "INVTYPE_SHIELD",
    ["弹药"] = "INVTYPE_AMMO",
    ["Head"] = "INVTYPE_HEAD",
    ["Neck"] = "INVTYPE_NECK",
    ["Shoulder"] = "INVTYPE_SHOULDER",
    ["Back"] = "INVTYPE_CLOAK",
    ["Chest"] = "INVTYPE_CHEST",
    ["Wrist"] = "INVTYPE_WRIST",
    ["Hands"] = "INVTYPE_HAND",
    ["Waist"] = "INVTYPE_WAIST",
    ["Legs"] = "INVTYPE_LEGS",
    ["Feet"] = "INVTYPE_FEET",
    ["Finger"] = "INVTYPE_FINGER",
    ["Trinket"] = "INVTYPE_TRINKET",
    ["Main Hand"] = "INVTYPE_WEAPONMAINHAND",
    ["Off Hand"] = "INVTYPE_WEAPONOFFHAND",
    ["One-Hand"] = "INVTYPE_WEAPON",
    ["Two-Hand"] = "INVTYPE_2HWEAPON",
    ["Ranged"] = "INVTYPE_RANGED",
    ["Shield"] = "INVTYPE_SHIELD",
    ["Ammo"] = "INVTYPE_AMMO",
};

-- 布局常量
local gQS_CellSize = 36;
local gQS_CellGap = 0;         -- 栏位条间距（0 = 边框环互相贴住，TrinketMenu 观感）
local gQS_PopupGap = 0;        -- 弹出列表格子间距（同为紧贴）
local gQS_PopupCols = 3;       -- 弹出列表默认列数（实际按数量自适应，TrinketMenu.BuildMenu 同款）
local gQS_MaxItems = 30;       -- 弹出列表容量（TrinketMenu.MaxTrinkets 同款 30）
local gQS_ConfigCols = 3;      -- 「快捷换装」页每行复选框数

--------------------------------------------------------------------------
-- 工具
--------------------------------------------------------------------------

function OutfitterQuickSwap_Message(pText)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33aaff[快速换装]|r " .. pText);
    end
end

-- 冷却剩余时间文字（TrinketMenu.WriteCooldown 同款格式：" s"/" m"/" h" 带空格）
function OutfitterQuickSwap_FormatCooldownText(pRemaining)
    if pRemaining < 60 then
        return math.floor(pRemaining + 0.5) .. " s";
    elseif pRemaining < 3600 then
        return math.ceil(pRemaining / 60) .. " m";
    else
        return math.ceil(pRemaining / 3600) .. " h";
    end
end

-- 统一设置冷却转盘 + 倒计时文字
-- 注意：与角色面板（CharacterTrinket1Slot）一致，CooldownFrame_SetTimer 只能在
-- 冷却参数变化时调用——OnUpdate 每 0.5s 的轮询若反复调用会不断重启原生扫盘动画，
-- 导致转盘和装备栏看起来不一样（只有文字在走）。
--
-- 倒计时文字完全按 TrinketMenu.WriteCooldown 的逻辑：
--   1) start==0 或「冷却计时」开关关 → 清空文字（转盘不受影响，照常扫盘）
--   2) 剩余<3s 且当前无文字 → 公共冷却，跳过不显示
--      （TrinketMenu 依赖 1.12 GetText() 空时返回 nil；这里两种空都按无文字处理）
--      已有文字的（真冷却走秒到 3s 以下）则继续显示到结束
--   3) 其余 → "12 s" / "5 m" / "1 h"（floor(+0.5) / ceil / ceil）
function OutfitterQuickSwap_SetCooldownDisplay(pButton, pStart, pDuration)
    local vStart = pStart or 0;
    local vDuration = pDuration or 0;

    if pButton.Cooldown then
        -- 参数变化时重设；另外若记录着冷却中但帧自身没被 Show（上次 SetTimer 因帧
        -- 不可见被引擎跳过，转盘和 pfUI/OmniCC 外部文字都会失效），补发一次。
        -- SetTimer 应用成功后帧必然 IsShown，因此不会反复触发。
        if pButton.CooldownStart ~= vStart or pButton.CooldownDuration ~= vDuration
            or (vStart > 0 and not pButton.Cooldown:IsShown()) then
            pButton.CooldownStart = vStart;
            pButton.CooldownDuration = vDuration;
            pcall(CooldownFrame_SetTimer, pButton.Cooldown, vStart, vDuration, 1);
        end
    end

    if pButton.CooldownText then
        -- TrinketMenu: cooldown = duration - (GetTime() - start)
        local vCooldown = 0;

        if vDuration > 0 and vStart > 0 then
            vCooldown = vDuration - (GetTime() - vStart);
        end

        local vText = pButton.CooldownText:GetText();

        if vStart == 0 or not gOutfitterQuickSwap_Settings.CooldownCount then
            pButton.CooldownText:SetText("");
            pButton.CooldownText:Hide();
        elseif vCooldown < 3 and (not vText or vText == "") then
            -- 公共冷却：跳过（保持无文字）
        else
            pButton.CooldownText:SetText(OutfitterQuickSwap_FormatCooldownText(vCooldown));
            pButton.CooldownText:Show();
        end
    end
end

--------------------------------------------------------------------------
-- 迷你提示（TrinketMenu TooltipUpdate/ShrinkTooltip 同款移植）
--------------------------------------------------------------------------

-- 充能行/冷却行识别串（TrinketMenu 顶部预处理同款）
-- "%1$d" 重排格式归一为 "%d"（充能格式串本身作为 Lua 模式时 "%d" 恰好匹配数字）
if ITEM_SPELL_CHARGES then
    OutfitterQuickSwap_ITEM_SPELL_CHARGES = string.gsub(ITEM_SPELL_CHARGES, "%%%d%$d", "%%d");
end

if ITEM_SPELL_CHARGES_P1 then
    OutfitterQuickSwap_ITEM_SPELL_CHARGES_P1 = string.gsub(ITEM_SPELL_CHARGES_P1, "%%%d%$d", "%%d");
end

-- 冷却行固定前缀（COOLDOWN_REMAINING 去掉 %s 之后的格式部分，做 plain 查找；
-- 再加两个硬编码兜底，防客户端本地化串差异）
OutfitterQuickSwap_cCooldownPrefixes = {};

if COOLDOWN_REMAINING then
    local vPrefix = string.match(COOLDOWN_REMAINING, "^(.-)%%s");

    if vPrefix and vPrefix ~= "" then
        table.insert(OutfitterQuickSwap_cCooldownPrefixes, vPrefix);
    end
end

table.insert(OutfitterQuickSwap_cCooldownPrefixes, "冷却剩余时间");
table.insert(OutfitterQuickSwap_cCooldownPrefixes, "Cooldown remaining");

-- tooltip 锚定（TrinketMenu.AnchorTooltip 同款）：默认走 GameTooltip_SetDefaultAnchor，
-- 让 pfUI / zTip 等提示增强插件接管锚点（它们 hook 的是这个函数，SetOwner 会绕过它们导致锚点漂移）。
-- 无该函数的环境回退 SetOwner 按钮右侧。
function OutfitterQuickSwap_AnchorTooltip(pOwner)
    pOwner = pOwner or this;
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, pOwner);
    else
        GameTooltip:SetOwner(pOwner, "ANCHOR_RIGHT");
    end
end

-- 迷你提示精简（TrinketMenu.ShrinkTooltip 同款）：只保留 名字(原色)/充能/冷却剩余。
-- 注意 TrinketMenu 的手法：先 SetInventoryItem/SetBagItem 填充完整 tooltip 读出所需行，
-- 再用 SetOwner（清空内容）+ AddLine 重建精简版。关闭迷你提示时此函数不改动任何内容。
function OutfitterQuickSwap_ShrinkTooltip(pOwner)
    if not gOutfitterQuickSwap_Settings.TinyTooltip then
        return;
    end

    local vFirst = getglobal("GameTooltipTextLeft1");

    if not vFirst or not vFirst:IsShown() then
        return;
    end

    local vR, vG, vB = vFirst:GetTextColor();
    local vName = vFirst:GetText();
    local vCooldown, vCharge;

    for vIndex = 2, 12 do
        local vLine = getglobal("GameTooltipTextLeft" .. vIndex);

        if vLine and vLine:IsShown() then
            local vText = vLine:GetText() or "";

            if vText ~= "" then
                if not vCooldown then
                    for _, vPrefix in OutfitterQuickSwap_cCooldownPrefixes do
                        if string.find(vText, vPrefix, 1, true) then
                            vCooldown = vText;
                            break;
                        end
                    end
                end

                if not vCharge and (
                    (OutfitterQuickSwap_ITEM_SPELL_CHARGES and string.find(vText, OutfitterQuickSwap_ITEM_SPELL_CHARGES))
                    or (OutfitterQuickSwap_ITEM_SPELL_CHARGES_P1 and string.find(vText, OutfitterQuickSwap_ITEM_SPELL_CHARGES_P1))
                ) then
                    vCharge = vText;
                end
            end
        end
    end

    OutfitterQuickSwap_AnchorTooltip(pOwner);

    if vName then
        GameTooltip:AddLine(vName, vR, vG, vB);
    end

    if vCharge then
        GameTooltip:AddLine(vCharge, 1, 1, 1);
    end

    if vCooldown then
        GameTooltip:AddLine(vCooldown, 1, 1, 1);
    end
end

-- 结束悬停刷新（各按钮 OnLeave / 弹框收起时调用）
function OutfitterQuickSwap_ClearTooltip()
    GameTooltip:Hide();
    gQS_TooltipType = nil;
    gQS_TooltipOwner = nil;
    gQS_TooltipBag = nil;
    gQS_TooltipSlot = nil;
end

-- tooltip 内容刷新（TrinketMenu.TooltipUpdate 同款）：
-- 每 1s 重设一次物品内容 → 冷却行实时走秒；无冷却时停止定时刷新；
-- 已穿戴物品若在战斗队列中，附加「已排队」行。
function OutfitterQuickSwap_TooltipUpdate()
    if not gQS_TooltipType or not gQS_TooltipOwner then
        return;
    end

    local vCooldownStart;

    if gQS_TooltipType == "BAG" then
        if not gQS_TooltipBag or not GetContainerItemLink(gQS_TooltipBag, gQS_TooltipSlot) then
            -- 物品已不在原格（换装等），停止刷新
            OutfitterQuickSwap_ClearTooltip();
            return;
        end

        OutfitterQuickSwap_AnchorTooltip(gQS_TooltipOwner);
        GameTooltip:SetBagItem(gQS_TooltipBag, gQS_TooltipSlot);
        vCooldownStart = GetContainerItemCooldown(gQS_TooltipBag, gQS_TooltipSlot);
    else
        OutfitterQuickSwap_AnchorTooltip(gQS_TooltipOwner);
        GameTooltip:SetInventoryItem("player", gQS_TooltipSlot);
        vCooldownStart = GetInventoryItemCooldown("player", gQS_TooltipSlot);
    end

    -- 迷你提示开启时在此精简（TrinketMenu 同款时序）
    OutfitterQuickSwap_ShrinkTooltip(gQS_TooltipOwner);

    if gQS_TooltipType == "INVENTORY" and gQS_TooltipOwner.Slot then
        if gQS_CombatQueue[gQS_TooltipOwner.Slot] then
            GameTooltip:AddLine("已排队：" .. gQS_CombatQueue[gQS_TooltipOwner.Slot]);
        end

        -- 自动排队列表（TrinketMenu 队列展示同款）
        local vQueue = gOutfitterQuickSwap_Settings.Queues[gQS_TooltipOwner.Slot];

        if vQueue and table.getn(vQueue) > 0 then
            GameTooltip:AddLine("自动排队：");

            for vIndex = 1, table.getn(vQueue) do
                -- 优先物品加「[优先]」标记（TrinketMenu 排队窗优先勾选同款展示）
                local vMark = gOutfitterQuickSwap_Settings.QueuePriorities[vQueue[vIndex]]
                    and " [优先]" or "";

                GameTooltip:AddLine("  " .. vIndex .. ". " .. vQueue[vIndex] .. vMark, 0.7, 0.7, 0.7);
            end
        end

        -- Alt+左键 加入/移出自动排队提示（当前已穿戴物品；与弹出列表 Alt+左键同语义）
        GameTooltip:AddLine("Alt+左键 加入/移出自动排队（当前已穿戴）", 0.5, 0.8, 1);
    elseif gQS_TooltipType == "BAG" and gQS_PopupSlot then
        -- 弹出列表物品：Alt+左键 增减自动排队（TrinketMenu Alt+点饰品开队列同款手感）
        local vLink = GetContainerItemLink(gQS_TooltipBag, gQS_TooltipSlot);
        local vName = string.match(vLink or "", "%[(.-)%]");

        if vName then
            local vInQueue = nil;
            local vQueue = gOutfitterQuickSwap_Settings.Queues[gQS_PopupSlot];

            if vQueue then
                for vIndex = 1, table.getn(vQueue) do
                    if vQueue[vIndex] == vName then
                        vInQueue = vIndex;
                        break;
                    end
                end
            end

            if vInQueue then
                local vDelay = gOutfitterQuickSwap_Settings.QueueDelays
                    and gOutfitterQuickSwap_Settings.QueueDelays[vName];

                GameTooltip:AddLine("Alt+左键 移出自动排队（当前第 " .. vInQueue .. " 位）", 0.5, 0.8, 1);
                GameTooltip:AddLine("Ctrl+左键 设置排队延迟", 0.5, 0.8, 1);

                if gOutfitterQuickSwap_Settings.QueuePriorities[vName] then
                    GameTooltip:AddLine("已设优先：一就绪立即换上使用", 1, 0.82, 0.2);
                end

                if vDelay and vDelay > 0 then
                    GameTooltip:AddLine("当前延迟：" .. vDelay .. " 秒（触发后保护期）", 0.7, 0.7, 0.7);
                end
            else
                GameTooltip:AddLine("Alt+左键 加入自动排队", 0.5, 0.8, 1);
            end
        end
    end

    GameTooltip:Show();

    if not vCooldownStart or vCooldownStart == 0 then
        -- 无冷却：停止每秒刷新（TrinketMenu 同款）
        gQS_TooltipType = nil;
        gQS_TooltipOwner = nil;
    end
end

-- 悬停登记 + 立即显示一次（后续走秒由事件帧 OnUpdate 驱动）
function OutfitterQuickSwap_ShowItemTooltip(pType, pOwner, pBag, pSlotID)
    gQS_TooltipType = pType;
    gQS_TooltipOwner = pOwner;
    gQS_TooltipBag = pBag;
    gQS_TooltipSlot = pSlotID;
    gQS_TooltipNext = 0;
    OutfitterQuickSwap_TooltipUpdate();
end

-- 判定玩家是否真的死亡/灵魂状态（TrinketMenu.IsPlayerReallyDead 同款：假死不算）
function OutfitterQuickSwap_IsPlayerReallyDead()
    local vDead = UnitIsDeadOrGhost("player");

    for vIndex = 1, 24 do
        if UnitBuff("player", vIndex) == "Interface\\Icons\\Ability_Rogue_FeignDeath" then
            vDead = nil;
        end
    end

    return vDead;
end

-- 按物品名在背包中查找位置（TrinketMenu.FindItem 同款，plain 查找防特殊字符）
function OutfitterQuickSwap_FindItemByName(pName)
    if not pName then
        return nil;
    end

    for vBag = 0, 4 do
        for vSlot = 1, GetContainerNumSlots(vBag) do
            local vLink = GetContainerItemLink(vBag, vSlot);

            if vLink and string.find(vLink, pName, 1, true) then
                return vBag, vSlot;
            end
        end
    end

    return nil;
end

-- 更新指定部位的排队角标（TrinketMenu.UpdateCombatQueue 模式：显示排队物品的小图标）
-- 战斗队列优先（原色）；无战斗队列时显示自动排队首物品（淡蓝色，TrinketMenu 齿轮角标同位）
function OutfitterQuickSwap_UpdateQueueMark(pSlotName)
    for vIndex = 1, table.getn(gQS_SlotButtons) do
        local vButton = gQS_SlotButtons[vIndex];

        if vButton.Slot == pSlotName and vButton.QueueIcon then
            local vName = gQS_CombatQueue[pSlotName];
            local vAuto = false;

            if not vName then
                local vQueue = gOutfitterQuickSwap_Settings.Queues[pSlotName];

                if vQueue and table.getn(vQueue) > 0 then
                    vName = vQueue[1];
                    vAuto = true;
                end
            end

            local vBag, vSlot = OutfitterQuickSwap_FindItemByName(vName);

            if vBag then
                vButton.QueueIcon:SetTexture(GetContainerItemInfo(vBag, vSlot));

                if vAuto then
                    -- 该部位排队暂停时染红（TrinketMenu.UpdateQueueIcon 同款 1,.5,.5）
                    if gOutfitterQuickSwap_Settings.PausedSlots[pSlotName] then
                        vButton.QueueIcon:SetVertexColor(1, 0.5, 0.5);
                    else
                        vButton.QueueIcon:SetVertexColor(0.6, 0.8, 1);
                    end
                else
                    vButton.QueueIcon:SetVertexColor(1, 1, 1);
                end

                vButton.QueueIcon:Show();
            else
                vButton.QueueIcon:Hide();
            end
        end
    end
end

-- 重建栏位条后同步所有排队角标（战斗队列 + 自动排队）
function OutfitterQuickSwap_RefreshQueueMarks()
    for vSlotName, _ in pairs(gQS_CombatQueue) do
        OutfitterQuickSwap_UpdateQueueMark(vSlotName);
    end

    for vSlotName, _ in pairs(gOutfitterQuickSwap_Settings.Queues) do
        OutfitterQuickSwap_UpdateQueueMark(vSlotName);
    end
end

--------------------------------------------------------------------------
-- 按键绑定（TrinketMenu.ReflectKeyBindings 同款）
--------------------------------------------------------------------------

-- 按键执行：使用指定部位已穿戴的物品（TrinketMenu "Use Top Trinket" 同款 UseInventoryItem）
function OutfitterQuickSwap_UseSlot(pSlotName)
    if not pSlotName then
        return;
    end

    local vSlotID = GetInventorySlotInfo(pSlotName);

    if vSlotID then
        UseInventoryItem(vSlotID);
    end
end

-- 把绑定键文字刷到各装备按钮上（开关关闭或未绑定 → 清空，TrinketMenu 同款行为）
function OutfitterQuickSwap_ReflectKeyBindings()
    for vIndex = 1, table.getn(gQS_SlotButtons) do
        local vButton = gQS_SlotButtons[vIndex];
        local vHotKey = vButton.HotKey;

        if vHotKey then
            local vText = "";

            if gOutfitterQuickSwap_Settings.ShowHotKeys and vButton.Slot then
                local vKey = GetBindingKey(OutfitterQuickSwap_cBindPrefix .. string.upper(vButton.Slot));

                if vKey then
                    vText = GetBindingText(vKey, "KEY_", 1) or "";
                end
            end

            vHotKey:SetText(vText);
        end
    end
end

-- 隐藏 tooltip 扫描 equipLoc（GetItemInfo 失败/未缓存时回退）
function OutfitterQuickSwap_ScanTooltipEquipLoc(pBag, pSlot)
    local vTooltip = gQS_ScanTooltip;
    vTooltip:SetOwner(UIParent, "ANCHOR_NONE");
    vTooltip:SetBagItem(pBag, pSlot);

    -- 数据完整才判定（第一行必须可见）
    local vFirst = getglobal("OutfitterQuickSwapScanTooltipTextLeft1");
    if not vFirst or not vFirst:IsShown() then
        vTooltip:Hide();
        return nil;
    end

    local vEquipLoc = nil;

    for vIndex = 2, 8 do
        local vFS = getglobal("OutfitterQuickSwapScanTooltipTextLeft" .. vIndex);
        if vFS then
            local vText = vFS:GetText();
            if vText and vText ~= "" then
                vText = string.gsub(vText, "%s+", "");
                local vInvType = OutfitterQuickSwap_cCNLabelToInvType[vText];
                if not vInvType then
                    -- "装备：头部" / "Equip: Head" 形式
                    local vAfter = string.match(vText, "^装备：(.+)$") or string.match(vText, "^Equip:%s*(.+)$");
                    if vAfter then
                        vInvType = OutfitterQuickSwap_cCNLabelToInvType[vAfter];
                    end
                end
                if vInvType then
                    vEquipLoc = vInvType;
                    break;
                end
            end
        end
    end

    vTooltip:Hide();
    return vEquipLoc;
end

-- 读取背包物品信息（布局无关：按返回值特征扫描）
function OutfitterQuickSwap_GetBagItem(pBag, pSlot)
    local vLink = GetContainerItemLink(pBag, pSlot);
    if not vLink then
        return nil;
    end

    local vInfo = { Bag = pBag, Slot = pSlot, Link = vLink };
    vInfo.Name = string.match(vLink, "%[(.-)%]");

    -- Outfitter 自带识别（角色面板槽位弹窗同源，本客户端已验证可靠）
    if Outfitter_GetItemInfoFromLink then
        local vOutOK, vOutItem = pcall(Outfitter_GetItemInfoFromLink, vLink);

        if vOutOK and vOutItem then
            vInfo.ItemSlotName = vOutItem.ItemSlotName;
            vInfo.MetaSlotName = vOutItem.MetaSlotName;
        end
    end

    -- GetItemInfo：传入完整彩色链接字符串，pcall 包裹
    local vOK, vR1, vR2, vR3, vR4, vR5, vR6, vR7, vR8 = pcall(GetItemInfo, vLink);

    if vOK and vR1 then
        -- 布局无关扫描：equipLoc 是 ^INVTYPE_ 开头；quality 取第一个 0-6 数字
        local vArgs = { vR1, vR2, vR3, vR4, vR5, vR6, vR7, vR8 };
        local vQualityFound = nil;

        for vIndex = 1, table.getn(vArgs) do
            local v = vArgs[vIndex];
            if type(v) == "string" then
                if string.find(v, "^INVTYPE_") and not vInfo.EquipLoc then
                    vInfo.EquipLoc = v;
                end
            elseif type(v) == "number" and not vQualityFound and v >= 0 and v <= 6 then
                vQualityFound = v;
            end
        end

        vInfo.Quality = vQualityFound;
    end

    if not vInfo.EquipLoc then
        vInfo.EquipLoc = OutfitterQuickSwap_ScanTooltipEquipLoc(pBag, pSlot);
    end

    local vTexture, vCount = GetContainerItemInfo(pBag, pSlot);
    vInfo.Texture = vTexture;
    vInfo.Count = vCount;

    return vInfo;
end

-- 判断背包物品是否匹配指定部位（优先 Outfitter 的 ItemSlotName，equipLoc 兜底）
function OutfitterQuickSwap_ItemMatchesSlot(pInfo, pSlotName)
    if not pInfo then
        return false;
    end

    if pInfo.ItemSlotName == pSlotName or pInfo.MetaSlotName == pSlotName then
        return true;
    end

    -- Outfitter 把戒指/饰品统一映射到 0 号槽，弹 1 号槽时也匹配
    if pSlotName == "Finger1Slot" and pInfo.ItemSlotName == "Finger0Slot" then
        return true;
    end

    if pSlotName == "Trinket1Slot" and pInfo.ItemSlotName == "Trinket0Slot" then
        return true;
    end

    local vAccept = OutfitterQuickSwap_cSlotAccept[pSlotName];

    if vAccept and pInfo.EquipLoc and vAccept[pInfo.EquipLoc] then
        return true;
    end

    return false;
end

-- 收集背包中匹配指定部位的物品
-- pShowHidden: true ＝ 含屏蔽物品（按住 Alt 时弹列表用）；默认过滤掉屏蔽物品
function OutfitterQuickSwap_CollectBagItems(pSlotName, pShowHidden)
    local vItems = {};
    local vHidden = gOutfitterQuickSwap_Settings.HiddenItems or {};

    for vBag = 0, 4 do
        local vNumSlots = GetContainerNumSlots(vBag);

        for vSlot = 1, vNumSlots do
            local vInfo = OutfitterQuickSwap_GetBagItem(vBag, vSlot);

            if vInfo and OutfitterQuickSwap_ItemMatchesSlot(vInfo, pSlotName) then
                if pShowHidden or not vHidden[vInfo.Name] then
                    table.insert(vItems, vInfo);
                end
            end
        end
    end

    return vItems;
end

-- 屏蔽/恢复弹出列表中的某物品（Alt+右键弹出物品触发），返回屏蔽后状态（true=屏蔽中）
function OutfitterQuickSwap_ToggleHiddenItem(pItemName)
    local vHidden = gOutfitterQuickSwap_Settings.HiddenItems;

    if vHidden[pItemName] then
        vHidden[pItemName] = nil;
    else
        vHidden[pItemName] = true;
    end

    OutfitterQuickSwap_SaveSettings();
    return vHidden[pItemName] and true or false;
end

--------------------------------------------------------------------------
-- 设置（随角色保存到 gOutfitter_Settings.QuickSwap）
--------------------------------------------------------------------------

-- 默认位置（从未保存过 X/Y 时调用）：用户指定 (1122.53, 275.53)，
-- 与 TrinketMenu 默认区域（X=400 一带）相距甚远，无重叠，无需避让分支
function OutfitterQuickSwap_ApplyDefaultPosition()
    OutfitterQuickSwapFrame:ClearAllPoints();

    -- 默认锚定 BCS 属性悬浮窗正上方：右下角默认落点与 pfUI 目标头像重叠
    -- （2026-10-05 实报）。BCS 悬浮窗没有全局名字，走 BCS.PropertiesPanel.frame
    -- 引用；PLAYER_ENTERING_WORLD 时 BCS 已定位完，相对锚定还能贴着它走。
    -- 相对锚定只在未拖动期间生效：一旦拖过，OnMouseUp → ReanchorFrame 会
    -- 重锚回 UIParent 绝对坐标并入存档，之后与 BCS 解耦。
    local vBcsPanel = BCS and BCS.PropertiesPanel and BCS.PropertiesPanel.frame;
    if vBcsPanel then
        OutfitterQuickSwapFrame:SetPoint("BOTTOMLEFT", vBcsPanel, "TOPLEFT", 0, 6);
    else
        -- BCS 未装/未加载：退回原右下角固定落点
        OutfitterQuickSwapFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 1122.531336708608, 275.5310979687554);
    end
end

function OutfitterQuickSwap_LoadSettings()
    if not gOutfitter_Settings or not gOutfitter_Settings.QuickSwap then
        -- 全新角色（还没有 QuickSwap 存档）：默认隐藏，等第一个饰品再自动弹出
        -- （TrinketMenu 逻辑：没饰品不显示主框）
        gOutfitterQuickSwap_Settings.AutoShown = false;
        gOutfitterQuickSwap_Settings.Enabled = false;

        -- 新角色路径不会走到下面通用的 ApplyPanelStyle（提前 return 了），
        -- 必须在这里先把精简模式落到框体上：否则首个饰品触发自动弹出时，
        -- 框体还带着创建期的经典外观（背景框/标题栏/关闭按钮）整套显示
        OutfitterQuickSwap_ApplyDefaultPosition();
        OutfitterQuickSwap_ApplyPanelStyle();
        return;
    end

    local vSettings = gOutfitter_Settings.QuickSwap;

    -- 存档有非空 Slots 才覆盖默认；空表（从未勾选过/旧版默认空）视为未配置，
    -- 保留默认的两个饰品勾选——避免栏位条弹出后是空壳
    local vHasSlots = false;
    if vSettings.Slots then
        for _, vSlot in OutfitterQuickSwap_cSlots do
            if vSettings.Slots[vSlot.Slot] then
                vHasSlots = true;
                break;
            end
        end
    end

    -- 存档标记为"用户已配置过"（含主动全部取消）时照原样应用——否则空表
    -- 会被判为"从未配置"，全取消后重登回弹成默认两个饰品（同类设置丢失 bug）
    if vHasSlots or vSettings.SlotsConfigured then
        gOutfitterQuickSwap_EnabledSlots = {};
        for _, vSlot in OutfitterQuickSwap_cSlots do
            if vSettings.Slots[vSlot.Slot] then
                gOutfitterQuickSwap_EnabledSlots[vSlot.Slot] = true;
            end
        end
    end

    if vSettings.Enabled ~= nil then
        gOutfitterQuickSwap_Settings.Enabled = vSettings.Enabled and true or false;
    elseif vSettings.Visible ~= nil then
        gOutfitterQuickSwap_Settings.Enabled = vSettings.Visible and true or false;
    end

    -- 首个饰品自动弹出标记：新存档字段缺失时视为"已弹出过"（旧角色不被强制弹框）
    if vSettings.AutoShown ~= nil then
        gOutfitterQuickSwap_Settings.AutoShown = vSettings.AutoShown and true or false;
    else
        gOutfitterQuickSwap_Settings.AutoShown = true;
    end

    if vSettings.Compact ~= nil then
        gOutfitterQuickSwap_Settings.Compact = vSettings.Compact and true or false;
    end

    -- 自动排队列表（[部位名] = 物品名数组，引用存档表即可）
    if vSettings.Queues then
        gOutfitterQuickSwap_Settings.Queues = vSettings.Queues;
    end

    -- 每物品排队延迟（[物品名] = 秒数）。⚠️ 此前只写不读（SaveSettings 有、
    -- LoadSettings 漏了迁移段）→ 设好的延迟重登即丢，必须保留此段
    if vSettings.QueueDelays then
        gOutfitterQuickSwap_Settings.QueueDelays = vSettings.QueueDelays;
    end

    -- 优先物品（[物品名]=true）
    if vSettings.QueuePriorities then
        gOutfitterQuickSwap_Settings.QueuePriorities = vSettings.QueuePriorities;
    end

    -- 锁定 / 按部位暂停排队（TrinketMenu Locked / SetQueue PAUSE 同款）
    if vSettings.Locked ~= nil then
        gOutfitterQuickSwap_Settings.Locked = vSettings.Locked and true or false;
    end

    if vSettings.PausedSlots then
        gOutfitterQuickSwap_Settings.PausedSlots = vSettings.PausedSlots;
    end

    if vSettings.HiddenItems then
        gOutfitterQuickSwap_Settings.HiddenItems = vSettings.HiddenItems;
    end

    if vSettings.ShowHotKeys ~= nil then
        gOutfitterQuickSwap_Settings.ShowHotKeys = vSettings.ShowHotKeys and true or false;
    end

    if vSettings.PopupUp ~= nil then
        gOutfitterQuickSwap_Settings.PopupUp = vSettings.PopupUp and true or false;
    end

    if vSettings.TinyTooltip ~= nil then
        gOutfitterQuickSwap_Settings.TinyTooltip = vSettings.TinyTooltip and true or false;
    end

    -- 备选框常显（TrinketMenu KeepOpen 同款）——必须与 SaveSettings 成对，否则设好重登即丢
    if vSettings.PopupAlways ~= nil then
        gOutfitterQuickSwap_Settings.PopupAlways = vSettings.PopupAlways and true or false;
    end

    -- 饰品模式（TrinketMenu 主框定位同款）——与 SaveSettings 成对
    if vSettings.TrinketMode ~= nil then
        gOutfitterQuickSwap_Settings.TrinketMode = vSettings.TrinketMode and true or false;
    end

    -- 竖向排列（false = 横向）——与 SaveSettings 成对
    if vSettings.Vertical ~= nil then
        gOutfitterQuickSwap_Settings.Vertical = vSettings.Vertical and true or false;
    end

    if vSettings.CooldownCount ~= nil then
        gOutfitterQuickSwap_Settings.CooldownCount = vSettings.CooldownCount and true or false;
    end

    if vSettings.Scale then
        gOutfitterQuickSwap_Settings.Scale = math.min(2, math.max(0.5, tonumber(vSettings.Scale) or 1));
    end

    -- ⚠️ 顺序铁律：先 SetScale，再 SetPoint。存档 X/Y 是缩放后的局部偏移
    -- （本客户端 GetLeft/SetPoint 偏移同单位，物理位置 = 偏移 × scale），
    -- 先把 scale 定好再用原值 SetPoint，落点才等于存档时的物理位置。
    -- （旧顺序 SetPoint→SetScale，且 SetScale 的重锚补偿在登录路径也执行——
    -- 本客户端隐藏框体的 GetLeft 非 nil，补偿把偏移放大 1/scale：scale 0.55
    -- 的号每次登录 X×1.82 复利膨胀，存档 X=3391 实锤；越界自愈再把超屏的
    -- X 拍回右下角 → 表现为"拖好的位置不保存"。TrinketMenu 恢复同样是
    -- 先 SetPoint 后裸 SetScale、不带补偿，见 TrinketMenu.lua:279-282）
    if OutfitterQuickSwap_SetScale then
        OutfitterQuickSwap_SetScale(gOutfitterQuickSwap_Settings.Scale or 1);
    end

    if vSettings.X and vSettings.Y then
        local vX = tonumber(vSettings.X);
        local vY = tonumber(vSettings.Y);

        -- 旧默认落点迁移：存档值 = 旧版默认（从未拖动过的号）→ 迁到 BCS 属性面板
        -- 上方（2026-10-05，旧默认与 pfUI 目标头像重叠）。真拖过的位置值不同，
        -- 不受影响。偏移 1 内判定（存档存 GetLeft 浮点原值，往返可能带尾差）。
        if vX and vY
            and math.abs(vX - 1122.531336708608) <= 1
            and math.abs(vY - 275.5310979687554) <= 1 then
            OutfitterQuickSwap_ApplyDefaultPosition();
        else
            -- 越界自愈（物理空间判定）：偏移是缩放局部单位，必须 ×scale 换算成
            -- UIParent 单位再和屏宽比——直接拿偏移比屏宽，scale<1 的号正常位置
            -- 也会被误判越界（表现同为"位置不保存"）。超界轴复位到右下角贴底。
            -- （X=4516 旧案即偏移膨胀 + 偏移单位误判越界的复合结果）
            local vScale = OutfitterQuickSwapFrame:GetScale() or 1;
            local vPhysX, vPhysY = vX * vScale, vY * vScale;
            local vScreenW, vScreenH = GetScreenWidth(), GetScreenHeight();

            if vPhysX > vScreenW + 300 or vPhysX < -500 then
                vX = (vScreenW - 320) / vScale;
            end

            if vPhysY > vScreenH + 300 or vPhysY < -500 then
                vY = 20 / vScale;
            end

            OutfitterQuickSwapFrame:ClearAllPoints();
            OutfitterQuickSwapFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", vX, vY);
        end
    else
        -- 从未保存过位置：按是否装了 TrinketMenu 选默认落点（避让其初始区域）
        OutfitterQuickSwap_ApplyDefaultPosition();
    end

    -- 分栏2（饰品模式第二栏）：先 SetScale 后 SetPoint（与分栏1 同一条顺序铁律）；
    -- Scale2/X2/Y2 与 SaveSettings 成对，防"写而不读"
    if OutfitterQuickSwap_SetScale2 then
        OutfitterQuickSwap_SetScale2(vSettings.Scale2 or 1);
    end

    if OutfitterQuickSwapFrame2 then
        -- Frame2PosValid 迁移标记：旧版 SaveSettings 无条件存 X2/Y2，把创建默认落点
        -- （UIParent 1122,180，宽屏下=屏幕最右侧）当成了用户位置存档。缺标记的旧存档
        -- 一律视为"从未定位"，走默认跟随锚定；只有新存档（用户真拖过/缩放过）才恢复
        if vSettings.X2 and vSettings.Y2 and vSettings.Frame2PosValid then
            local vX2 = tonumber(vSettings.X2);
            local vY2 = tonumber(vSettings.Y2);

            if vX2 and vY2 then
                gQS_Frame2Moved = true; -- 有用户存档位置：本会话视为"已接管"
                OutfitterQuickSwapFrame2:ClearAllPoints();
                OutfitterQuickSwapFrame2:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", vX2, vY2);
            end
        else
            -- 未定位：相对锚定在分栏1 正下方（随分栏1 移动，拖过/缩放后才入存档）
            OutfitterQuickSwap_DefaultFrame2Anchor();
        end
    end

    OutfitterQuickSwap_ApplyPanelStyle();

    if gOutfitterQuickSwap_Settings.Enabled then
        OutfitterQuickSwapFrame:Show();
    else
        OutfitterQuickSwapFrame:Hide();
    end
end

function OutfitterQuickSwap_SaveSettings()
    if not gOutfitter_Settings then
        return;
    end

    -- X/Y 直接存 GetLeft/GetBottom 原值：1.12 下 SetPoint 偏移与 GetLeft 同单位
    --（偏移 × 有效缩放 = 物理位置，TrinketMenu.ScaleFrame 公式反证），raw 存取往返精确，
    -- 不要做任何 ×scale/÷scale 换算（×GetScale 会让每次存档/切换按绝对坐标比例漂移）
    local vX, vY = OutfitterQuickSwapFrame:GetLeft(), OutfitterQuickSwapFrame:GetBottom();

    gOutfitter_Settings.QuickSwap = {
        Enabled = OutfitterQuickSwapFrame:IsShown() and true or false,
        AutoShown = gOutfitterQuickSwap_Settings.AutoShown,
        Compact = gOutfitterQuickSwap_Settings.Compact,
        PopupUp = gOutfitterQuickSwap_Settings.PopupUp,
        TinyTooltip = gOutfitterQuickSwap_Settings.TinyTooltip,
        PopupAlways = gOutfitterQuickSwap_Settings.PopupAlways,
        TrinketMode = gOutfitterQuickSwap_Settings.TrinketMode,
        Vertical = gOutfitterQuickSwap_Settings.Vertical,
        CooldownCount = gOutfitterQuickSwap_Settings.CooldownCount,
        Scale = gOutfitterQuickSwap_Settings.Scale or 1,
        Queues = gOutfitterQuickSwap_Settings.Queues,
        QueueDelays = gOutfitterQuickSwap_Settings.QueueDelays,
        QueuePriorities = gOutfitterQuickSwap_Settings.QueuePriorities,
        Locked = gOutfitterQuickSwap_Settings.Locked,
        PausedSlots = gOutfitterQuickSwap_Settings.PausedSlots,
        HiddenItems = gOutfitterQuickSwap_Settings.HiddenItems,
        ShowHotKeys = gOutfitterQuickSwap_Settings.ShowHotKeys,
        X = vX,
        Y = vY,
        -- 分栏2（饰品模式第二栏）位置与缩放（与 LoadSettings 成对）
        Scale2 = gOutfitterQuickSwap_Settings.Scale2 or 1,
        -- X2/Y2 只在用户拖动/缩放过分栏2（gQS_Frame2Moved）后持久化：
        -- 未接管时保持 nil，默认相对锚定"分栏1 正下方"，跟着分栏1 走
        X2 = gQS_Frame2Moved and OutfitterQuickSwapFrame2 and OutfitterQuickSwapFrame2:GetLeft() or nil,
        Y2 = gQS_Frame2Moved and OutfitterQuickSwapFrame2 and OutfitterQuickSwapFrame2:GetBottom() or nil,
        -- 迁移标记：有它 X2/Y2 才是"用户真定位过"的存档（LoadSettings 据此甄别旧版无条件存下的垃圾坐标）
        Frame2PosValid = gQS_Frame2Moved and true or nil,
        Slots = gOutfitterQuickSwap_EnabledSlots,
        SlotsConfigured = gOutfitterQuickSwap_Settings.SlotsConfigured,
    };
end

-- 拖拽结束后重锚 BOTTOMLEFT：1.12 StopMovingOrSizing 会把框体留在 TOPLEFT 锚点上
-- （顶边固定），之后 SetHeight 增减会向下伸缩，锚定底边的栏位条就会跟着跳。
-- 位置不变（GetLeft/GetBottom 与 SetPoint 偏移同单位），只换锚点参考。
function OutfitterQuickSwap_ReanchorFrame()
    local vLeft, vBottom = OutfitterQuickSwapFrame:GetLeft(), OutfitterQuickSwapFrame:GetBottom();

    if not vLeft or not vBottom then
        return;
    end

    OutfitterQuickSwapFrame:ClearAllPoints();
    OutfitterQuickSwapFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", vLeft, vBottom);
end

-- 自动排队（TrinketMenuQueue 模式）：Alt+点弹出列表物品，把该物品加入/移出部位队列
-- 返回 true=已加入 / false=已移出；操作后立即存档
function OutfitterQuickSwap_ToggleQueueItem(pSlotName, pItemName)
    local vQueue = gOutfitterQuickSwap_Settings.Queues[pSlotName];

    if not vQueue then
        vQueue = {};
        gOutfitterQuickSwap_Settings.Queues[pSlotName] = vQueue;
    end

    for vIndex = 1, table.getn(vQueue) do
        if vQueue[vIndex] == pItemName then
            table.remove(vQueue, vIndex);
            OutfitterQuickSwap_SaveSettings();
            -- 排队设置窗口开着时同步内容
            if OutfitterQuickSwapQueueCfg and OutfitterQuickSwapQueueCfg:IsShown() then
                OutfitterQuickSwap_RebuildQueueCfg();
            end
            return false;
        end
    end

    table.insert(vQueue, pItemName);
    OutfitterQuickSwap_SaveSettings();
    if OutfitterQuickSwapQueueCfg and OutfitterQuickSwapQueueCfg:IsShown() then
        OutfitterQuickSwap_RebuildQueueCfg();
    end
    return true;
end

--------------------------------------------------------------------------
-- 自动排队设置窗口（TrinketMenu 排队管理窗口同款布局，参考 TrinketMenuQueue.xml）：
-- 顶部部位下拉选择 → 左侧排序按钮（顶/上/下/底）→ 物品列表（图标+品质色名字，
-- 点选高亮）→ 底部「延迟 [X] 秒 + 暂停该部位排队」作用于选中物品/部位。
-- 延迟语义 = TrinketMenu「延迟替换」Swap Delay：物品触发后 N 秒内排队不换下它。
-- （不设「停止排队线」行：本插件排队引擎按全员候选扫描，见 ProcessAutoQueue 注释）
--------------------------------------------------------------------------

local gQS_QueueCfgRows = {};          -- 列表行控件池（Button：图标+名字+选中高亮）
local gQS_QueueCfgListTop = -64;      -- 列表首行 y（下拉下方）
local gQS_QueueCfgRowHeight = 26;
local gQS_QueueCfgMaxRows = 10;       -- 可视行数上限（队列超过时超出部分不显示，实际很少超过）
local gQS_QueueCfgSlot = nil;         -- 当前编辑的部位名
local gQS_QueueCfgSel = nil;          -- 当前选中行（队列内序号，1 起）

-- 图标查找：背包 → 已穿戴 → nil（调用方兜底问号占位）
local function OutfitterQuickSwap_QueueCfgItemTexture(pName)
    local vBag, vSlot = OutfitterQuickSwap_FindItemByName(pName);

    if vBag then
        local vTexture = GetContainerItemInfo(vBag, vSlot);

        if vTexture then
            return vTexture;
        end
    end

    for vInv = 1, 19 do
        local vLink = GetInventoryItemLink("player", vInv);
        local vInvName = vLink and string.match(vLink, "%[(.-)%]");

        if vInvName == pName then
            return GetInventoryItemTexture("player", vInv);
        end
    end

    return nil;
end

-- 品质色（仅装饰用；查不到回退灰白。短链接提取裸 ID 传 GetItemInfo——
-- 与 Outfitter 存量路径同款（已缓存 ID 可用），整条链路 pcall 包裹）
local function OutfitterQuickSwap_QueueCfgItemColor(pName)
    local vBag, vSlot = OutfitterQuickSwap_FindItemByName(pName);

    if vBag then
        local vLink = GetContainerItemLink(vBag, vSlot);
        local vItemID = vLink and string.match(vLink, "item:(%d+)");

        if vItemID then
            local vOK, _, _, vQuality = pcall(GetItemInfo, tonumber(vItemID));

            if vOK and vQuality then
                local vOK2, vR, vG, vB = pcall(GetItemQualityColor, vQuality);

                if vOK2 then
                    return vR, vG, vB;
                end
            end
        end
    end

    return 0.85, 0.85, 0.85;
end

-- 懒创建窗口骨架
local function OutfitterQuickSwap_EnsureQueueCfgFrame()
    if OutfitterQuickSwapQueueCfg then
        return;
    end

    local vFrame = CreateFrame("Frame", "OutfitterQuickSwapQueueCfg", UIParent);
    vFrame:SetFrameStrata("HIGH");   -- 禁 TOOLTIP 层（GameTooltip 保留层，同层会被按钮盖住提示）
    vFrame:SetToplevel(true);
    vFrame:SetMovable(true);
    vFrame:EnableMouse(true);
    vFrame:SetWidth(300);
    vFrame:SetHeight(320);
    vFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 40);
    vFrame:Hide();

    vFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    });
    vFrame:SetBackdropColor(0, 0, 0, 0.9);

    -- ESC 关闭（StaticPopup 同款机制）
    table.insert(UISpecialFrames, "OutfitterQuickSwapQueueCfg");

    -- 标题栏（可拖动）
    local vTitleBar = CreateFrame("Frame", "OutfitterQuickSwapQueueCfgTitleBar", vFrame);
    vTitleBar:SetHeight(20);
    vTitleBar:SetPoint("TOPLEFT", vFrame, "TOPLEFT", 6, -6);
    vTitleBar:SetPoint("TOPRIGHT", vFrame, "TOPRIGHT", -28, -6);
    vTitleBar:EnableMouse(true);
    vTitleBar:SetScript("OnMouseDown", function()
        vFrame:StartMoving();
    end);
    vTitleBar:SetScript("OnMouseUp", function()
        vFrame:StopMovingOrSizing();
    end);

    local vTitle = vTitleBar:CreateFontString("OutfitterQuickSwapQueueCfgTitle", "OVERLAY", "GameFontNormal");
    vTitle:SetPoint("LEFT", vTitleBar, "LEFT", 2, 0);
    vTitle:SetText("自动排队设置");

    local vClose = CreateFrame("Button", "OutfitterQuickSwapQueueCfgClose", vFrame, "UIPanelCloseButton");
    vClose:SetPoint("TOPRIGHT", vFrame, "TOPRIGHT", -2, -2);

    -- 部位选择下拉（TrinketMenu 上/下两个页签 → 本插件部位多，改下拉，只列有排队的部位）
    local vDrop = CreateFrame("Frame", "OutfitterQuickSwapQueueCfgSlotDrop", vFrame, "UIDropDownMenuTemplate");
    vDrop:SetPoint("TOPLEFT", vFrame, "TOPLEFT", 4, -24);
    UIDropDownMenu_Initialize(vDrop, function()
        for _, vSlot in OutfitterQuickSwap_cSlots do
            local vQueue = gOutfitterQuickSwap_Settings.Queues[vSlot.Slot];

            if vQueue and table.getn(vQueue) > 0 then
                local vInfo = {};
                vInfo.text = vSlot.Short or vSlot.Label;
                vInfo.value = vSlot.Slot;
                vInfo.checked = (vSlot.Slot == gQS_QueueCfgSlot) and 1 or nil;
                vInfo.func = function()
                    gQS_QueueCfgSlot = this.value;
                    gQS_QueueCfgSel = nil;
                    OutfitterQuickSwap_RefreshQueueCfgList();
                end;
                UIDropDownMenu_AddButton(vInfo, 1);
            end
        end
    end);

    -- 空状态提示
    local vEmpty = vFrame:CreateFontString("OutfitterQuickSwapQueueCfgEmpty", "OVERLAY", "GameFontNormalSmall");
    vEmpty:SetPoint("TOPLEFT", vFrame, "TOPLEFT", 14, -70);
    vEmpty:SetWidth(272);
    vEmpty:SetJustifyH("LEFT");
    vEmpty:SetText("暂无自动排队：在弹出列表按住 Alt 左键点物品加入排队。");
    vEmpty:SetTextColor(0.6, 0.6, 0.6);
    vEmpty:Hide();

    -- 左侧排序按钮列（顶/上/下/底，TrinketMenu_MoveTop/Up/Down/Bottom 同职能）
    local vMoveDefs = {
        { Label = "顶", Dir = "top",    Tip = "移到队首" },
        { Label = "上", Dir = "up",     Tip = "上移一位" },
        { Label = "下", Dir = "down",   Tip = "下移一位" },
        { Label = "底", Dir = "bottom", Tip = "移到队尾" },
    };

    for vMoveIndex, vDef in vMoveDefs do
        local vBtn = CreateFrame("Button", "OutfitterQuickSwapQueueCfgMove" .. vMoveIndex, vFrame);
        vBtn:SetWidth(22);
        vBtn:SetHeight(22);
        vBtn.Dir = vDef.Dir;
        vBtn.Tip = vDef.Tip;
        -- ⚠️ 本客户端（1.12）Button 没有 SetNormalFontObject/SetText 系字体方法（TBC 才有），
        -- 按钮文字用自建 FontString；启用/禁用态靠 Refresh 时手动改文字颜色
        local vLabel = vBtn:CreateFontString(vBtn:GetName() .. "Label", "OVERLAY", "GameFontNormalSmall");
        vLabel:SetAllPoints();
        vLabel:SetText(vDef.Label);
        vLabel:SetTextColor(0.9, 0.9, 0.9);
        vBtn.LabelText = vLabel;
        vBtn:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        });
        vBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.9);
        vBtn:SetScript("OnClick", function()
            OutfitterQuickSwap_QueueCfgMove(this.Dir);
        end);
        vBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
            GameTooltip:SetText(this.Tip or "");
            GameTooltip:Show();
        end);
        vBtn:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);
    end

    -- 列表行控件池（Button：图标 + 品质色名字 + 选中高亮，TrinketMenu_Sort 行同款）
    for vRowIndex = 1, gQS_QueueCfgMaxRows do
        local vRow = CreateFrame("Button", "OutfitterQuickSwapQueueCfgRow" .. vRowIndex, vFrame);
        vRow:SetWidth(244);
        vRow:SetHeight(gQS_QueueCfgRowHeight);

        -- 选中高亮（TrinketMenu 黄色渐变条同款贴图，选中时常显、悬停走 Button 高亮）
        local vSelTex = vRow:CreateTexture(vRow:GetName() .. "Sel", "BACKGROUND");
        vSelTex:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
        vSelTex:SetAllPoints();
        vSelTex:SetAlpha(0.45);
        vSelTex:Hide();
        vRow.SelTex = vSelTex;

        local vIcon = vRow:CreateTexture(vRow:GetName() .. "Icon", "ARTWORK");
        vIcon:SetWidth(22);
        vIcon:SetHeight(22);
        vIcon:SetPoint("LEFT", vRow, "LEFT", 2, 0);
        vIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
        vRow.Icon = vIcon;

        local vText = vRow:CreateFontString(vRow:GetName() .. "Name", "OVERLAY", "GameFontNormalSmall");
        vText:SetPoint("LEFT", vIcon, "RIGHT", 8, 0);
        vRow.NameText = vText;

        vRow:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
        if vRow.GetHighlightTexture and vRow:GetHighlightTexture() then
            vRow:GetHighlightTexture():SetAlpha(0.3);
        end

        vRow:SetScript("OnClick", function()
            -- 再点一次取消选中（TrinketMenu.SortOnClick 同款）
            gQS_QueueCfgSel = (gQS_QueueCfgSel == this.Index) and nil or this.Index;
            OutfitterQuickSwap_RefreshQueueCfgList();
        end);

        gQS_QueueCfgRows[vRowIndex] = vRow;
    end

    -- 底部控制条：「延迟 [X] 秒」作用于选中物品；「暂停该部位排队」作用于当前部位
    local vDelayLabel = vFrame:CreateFontString("OutfitterQuickSwapQueueCfgDelayLabel", "OVERLAY", "GameFontNormalSmall");
    vDelayLabel:SetPoint("BOTTOMLEFT", vFrame, "BOTTOMLEFT", 12, 16);
    vDelayLabel:SetText("延迟");

    local vDelayEdit = CreateFrame("EditBox", "OutfitterQuickSwapQueueCfgDelayEdit", vFrame, "InputBoxTemplate");
    vDelayEdit:SetWidth(34);
    vDelayEdit:SetHeight(16);
    vDelayEdit:SetPoint("BOTTOMLEFT", vFrame, "BOTTOMLEFT", 40, 13);
    vDelayEdit:SetMaxLetters(3);
    vDelayEdit:SetAutoFocus(false);
    pcall(vDelayEdit.SetNumeric, vDelayEdit, true);
    vDelayEdit:SetScript("OnEnterPressed", function()
        local vSelf = this;

        if not vSelf.ItemName then
            vSelf:ClearFocus();
            return;
        end

        local vDelay = math.floor(math.max(0, math.min(300, tonumber(vSelf:GetText()) or 0)));

        if vDelay == 0 then
            gOutfitterQuickSwap_Settings.QueueDelays[vSelf.ItemName] = nil;
            vSelf:SetText("");
        else
            gOutfitterQuickSwap_Settings.QueueDelays[vSelf.ItemName] = vDelay;
            vSelf:SetText(tostring(vDelay));
        end

        OutfitterQuickSwap_SaveSettings();
        OutfitterQuickSwap_Message("排队延迟 " .. vSelf.ItemName .. " = " .. (vDelay > 0 and (vDelay .. " 秒") or "无"));
        vSelf:ClearFocus();
    end);
    vDelayEdit:SetScript("OnEscapePressed", function()
        this:ClearFocus();
    end);

    local vSecLabel = vFrame:CreateFontString("OutfitterQuickSwapQueueCfgSecLabel", "OVERLAY", "GameFontNormalSmall");
    vSecLabel:SetPoint("LEFT", vDelayEdit, "RIGHT", 4, 0);
    vSecLabel:SetText("秒");

    -- 优先勾选框：作用于选中物品（TrinketMenu 排队窗「优先」同款）——
    -- 勾上后该物品一就绪就立即换上使用，不必等当前饰品进冷却
    local vPrioCheck = CreateFrame("CheckButton", "OutfitterQuickSwapQueueCfgPrioCheck", vFrame, "OptionsCheckButtonTemplate");
    vPrioCheck:SetWidth(18);
    vPrioCheck:SetHeight(18);
    vPrioCheck:SetPoint("LEFT", vSecLabel, "RIGHT", 8, 0);
    local vPrioText = getglobal("OutfitterQuickSwapQueueCfgPrioCheckText");

    if vPrioText then
        vPrioText:SetText("优先");
    end

    vPrioCheck:SetScript("OnClick", function()
        local vQueue = gQS_QueueCfgSlot and gOutfitterQuickSwap_Settings.Queues[gQS_QueueCfgSlot];
        local vSelName = gQS_QueueCfgSel and vQueue and vQueue[gQS_QueueCfgSel];

        if not vSelName then
            this:SetChecked(0);
            return;
        end

        gOutfitterQuickSwap_Settings.QueuePriorities[vSelName] = this:GetChecked() and true or nil;
        OutfitterQuickSwap_SaveSettings();
        OutfitterQuickSwap_Message("优先 " .. vSelName .. " = " .. (this:GetChecked() and "开（就绪即换上使用）" or "关"));
    end);

    local vPauseCheck = CreateFrame("CheckButton", "OutfitterQuickSwapQueueCfgPauseCheck", vFrame, "OptionsCheckButtonTemplate");
    vPauseCheck:SetWidth(18);
    vPauseCheck:SetHeight(18);
    vPauseCheck:SetPoint("BOTTOMRIGHT", vFrame, "BOTTOMRIGHT", -10, 14);
    vPauseCheck:SetHitRectInsets(-4, -80, -4, -4);
    local vPauseText = getglobal("OutfitterQuickSwapQueueCfgPauseCheckText");

    if vPauseText then
        vPauseText:SetText("暂停该部位排队");
        vPauseText:ClearAllPoints();
        vPauseText:SetPoint("RIGHT", vPauseCheck, "LEFT", -2, 0);
        vPauseText:Show();
    end

    vPauseCheck:SetScript("OnClick", function()
        if not gQS_QueueCfgSlot then
            this:SetChecked(0);
            return;
        end

        gOutfitterQuickSwap_Settings.PausedSlots[gQS_QueueCfgSlot] = this:GetChecked() and true or nil;
        OutfitterQuickSwap_SaveSettings();
        OutfitterQuickSwap_UpdateQueueMark(gQS_QueueCfgSlot);
    end);

    vFrame:SetScript("OnHide", function()
        -- 关窗时收回输入框焦点（防卡输入态）
        OutfitterQuickSwapQueueCfgDelayEdit:ClearFocus();
    end);

    -- pfUI 美化（pfui-skin.lua 提供统一入口：主框/关闭/下拉/排序按钮/列表行/
    -- 输入框/勾选框；非 pfUI 环境内部直接返回，保持经典底；幂等可重复调用）
    if OutfitterQuickSwap_QueueCfgSkin then
        OutfitterQuickSwap_QueueCfgSkin(vFrame);
    end
end

-- 排序按钮处理（TrinketMenu.SortMove 同款：remove + insert，保持选中跟随）
function OutfitterQuickSwap_QueueCfgMove(pDir)
    local vQueue = gQS_QueueCfgSlot and gOutfitterQuickSwap_Settings.Queues[gQS_QueueCfgSlot];
    local vSel = gQS_QueueCfgSel;

    if not vQueue or not vSel or not vQueue[vSel] then
        return;
    end

    local vN = table.getn(vQueue);
    local vNew = vSel;

    if pDir == "up" then
        vNew = vSel - 1;
    elseif pDir == "down" then
        vNew = vSel + 1;
    elseif pDir == "top" then
        vNew = 1;
    elseif pDir == "bottom" then
        vNew = vN;
    end

    if vNew < 1 or vNew > vN or vNew == vSel then
        return;
    end

    local vTemp = vQueue[vSel];
    table.remove(vQueue, vSel);
    table.insert(vQueue, vNew, vTemp);
    gQS_QueueCfgSel = vNew;

    OutfitterQuickSwap_SaveSettings();
    OutfitterQuickSwap_RefreshQueueCfgList();
end

-- 校正当前部位：无队列/部位失效时换第一个有排队的部位
local function OutfitterQuickSwap_QueueCfgEnsureSlot()
    local function _HasQueue(pSlotName)
        local vQueue = gOutfitterQuickSwap_Settings.Queues[pSlotName];
        return vQueue and table.getn(vQueue) > 0;
    end

    if gQS_QueueCfgSlot and _HasQueue(gQS_QueueCfgSlot) then
        return;
    end

    gQS_QueueCfgSlot = nil;
    gQS_QueueCfgSel = nil;

    for _, vSlot in OutfitterQuickSwap_cSlots do
        if _HasQueue(vSlot.Slot) then
            gQS_QueueCfgSlot = vSlot.Slot;
            return;
        end
    end
end

-- 刷新列表/按钮状态/底部控制（打开时、点选、排序、队列变动后调用）
function OutfitterQuickSwap_RefreshQueueCfgList()
    OutfitterQuickSwap_EnsureQueueCfgFrame();

    local vFrame = OutfitterQuickSwapQueueCfg;
    local vQueue = gQS_QueueCfgSlot and gOutfitterQuickSwap_Settings.Queues[gQS_QueueCfgSlot];
    local vN = vQueue and table.getn(vQueue) or 0;

    if gQS_QueueCfgSel and gQS_QueueCfgSel > vN then
        gQS_QueueCfgSel = nil;
    end

    -- 下拉标签（1.12 参数序为 (text, dropdown)；签名不符时 pcall 静默跳过，不影响功能）
    local vSlotLabel = "";

    for _, vSlot in OutfitterQuickSwap_cSlots do
        if vSlot.Slot == gQS_QueueCfgSlot then
            vSlotLabel = vSlot.Short or vSlot.Label;
            break;
        end
    end

    pcall(UIDropDownMenu_SetText, vSlotLabel, getglobal("OutfitterQuickSwapQueueCfgSlotDrop"));

    -- 行内容
    for vRowIndex = 1, gQS_QueueCfgMaxRows do
        local vRow = gQS_QueueCfgRows[vRowIndex];

        if vRowIndex <= vN then
            local vName = vQueue[vRowIndex];

            vRow:ClearAllPoints();
            vRow:SetPoint("TOPLEFT", vFrame, "TOPLEFT", 44, gQS_QueueCfgListTop - (vRowIndex - 1) * gQS_QueueCfgRowHeight);
            vRow.Index = vRowIndex;
            vRow.Icon:SetTexture(OutfitterQuickSwap_QueueCfgItemTexture(vName) or "Interface\\Icons\\INV_Misc_QuestionMark");
            vRow.NameText:SetText(vName);
            vRow.NameText:SetTextColor(OutfitterQuickSwap_QueueCfgItemColor(vName));

            if gQS_QueueCfgSel == vRowIndex then
                vRow.SelTex:Show();
            else
                vRow.SelTex:Hide();
            end

            vRow:Show();
        else
            vRow:Hide();
        end
    end

    -- 排序按钮：空队列整列隐藏（无物品可排序，留着只会超窗底/压住空状态提示）；
    -- 有队列时无选中全禁用，到顶禁上/顶、到底禁下/底（TrinketMenu.SortValidate 同款）。
    -- 文字为自建 FontString，不随 Enable/Disable 变色，启用态手动切色
    local vMoveStates = {
        top = gQS_QueueCfgSel ~= nil and gQS_QueueCfgSel > 1,
        up = gQS_QueueCfgSel ~= nil and gQS_QueueCfgSel > 1,
        down = gQS_QueueCfgSel ~= nil and gQS_QueueCfgSel < vN,
        bottom = gQS_QueueCfgSel ~= nil and gQS_QueueCfgSel < vN,
    };

    for vMoveIndex = 1, 4 do
        local vBtn = getglobal("OutfitterQuickSwapQueueCfgMove" .. vMoveIndex);

        if vBtn then
            if vN == 0 then
                vBtn:Hide();
            else
                vBtn:ClearAllPoints();
                vBtn:SetPoint("TOPLEFT", vFrame, "TOPLEFT", 14, gQS_QueueCfgListTop + 8 - (vMoveIndex - 1) * 30);
                vBtn:Show();

                if vMoveStates[vBtn.Dir] then
                    vBtn:Enable();

                    if vBtn.LabelText then
                        vBtn.LabelText:SetTextColor(0.9, 0.9, 0.9);
                    end
                else
                    vBtn:Disable();

                    if vBtn.LabelText then
                        vBtn.LabelText:SetTextColor(0.35, 0.35, 0.35);
                    end
                end
            end
        end
    end

    -- 底部控制：延迟框跟选中物品；暂停框跟当前部位
    local vSelName = gQS_QueueCfgSel and vQueue and vQueue[gQS_QueueCfgSel];
    local vDelay = vSelName and gOutfitterQuickSwap_Settings.QueueDelays
        and gOutfitterQuickSwap_Settings.QueueDelays[vSelName];

    OutfitterQuickSwapQueueCfgDelayEdit.ItemName = vSelName;
    OutfitterQuickSwapQueueCfgDelayEdit:SetText(vDelay and vDelay > 0 and tostring(vDelay) or "");

    OutfitterQuickSwapQueueCfgPauseCheck:SetChecked(
        gQS_QueueCfgSlot and gOutfitterQuickSwap_Settings.PausedSlots[gQS_QueueCfgSlot] and 1 or 0);

    -- 优先勾选框跟选中物品；无选中时强制不勾
    OutfitterQuickSwapQueueCfgPrioCheck:SetChecked(
        vSelName and gOutfitterQuickSwap_Settings.QueuePriorities[vSelName] and 1 or 0);

    if vN == 0 then
        OutfitterQuickSwapQueueCfgEmpty:Show();
        -- 空状态：排序按钮列已隐藏，高度只要容住空提示（两行）+ 底部控制条
        vFrame:SetHeight(math.abs(gQS_QueueCfgListTop) + 80);
    else
        OutfitterQuickSwapQueueCfgEmpty:Hide();
        -- 高度 = max(列表底, 排序按钮列底) + 底部控制条：行数少时按钮列（4 个 × 30）
        -- 比列表更高，只按行数算高度会让「延迟/暂停」行叠到「底」按钮上；
        -- 底衬 50 保证按钮列完整留在窗内
        local vListAbs = math.abs(gQS_QueueCfgListTop) + vN * gQS_QueueCfgRowHeight;
        local vMoveAbs = math.abs(gQS_QueueCfgListTop + 8 - 3 * 30) + 22;
        vFrame:SetHeight(math.max(vListAbs, vMoveAbs) + 50);
    end
end

-- 按当前存档重建窗口内容（打开时、以及窗口开着时队列变动都会调用）
function OutfitterQuickSwap_RebuildQueueCfg()
    OutfitterQuickSwap_QueueCfgEnsureSlot();
    OutfitterQuickSwap_RefreshQueueCfgList();
end

-- 打开排队设置窗口（右键菜单「自动排队设置…」/ 弹出列表 Ctrl+左键）
function OutfitterQuickSwap_OpenQueueCfg()
    OutfitterQuickSwap_RebuildQueueCfg();
    OutfitterQuickSwapQueueCfg:Show();
end

-- 弹出框缩放同步：跟随锚定按钮所属分栏框体的缩放（两分栏可各自缩放，
-- 弹出框锚在谁家的按钮上就用谁的比例，避免放大分栏2后弹出列表还是分栏1 的 100%）
function OutfitterQuickSwap_SyncPopupScale()
    if not OutfitterQuickSwapPopup then
        return;
    end

    local vFrame = OutfitterQuickSwapFrame;

    if gQS_PopupOwner and gQS_PopupOwner.GetParent and gQS_PopupOwner:GetParent() then
        vFrame = gQS_PopupOwner:GetParent();
    end

    if vFrame and vFrame.GetScale then
        OutfitterQuickSwapPopup:SetScale(vFrame:GetScale() or 1);
    end
end

-- 面板缩放（滚轮在栏位条/标题栏上滚动调节，0.5x - 2.0x）
function OutfitterQuickSwap_SetScale(pScale)
    if not OutfitterQuickSwapFrame then
        return;
    end

    pScale = math.min(2, math.max(0.5, math.floor(pScale * 100 + 0.5) / 100));
    gOutfitterQuickSwap_Settings.Scale = pScale;

    -- 缩放前后保持左下角屏幕位置不动（TrinketMenu.ScaleFrame 同款补偿）：
    -- 偏移 × 有效缩放 = 物理位置，直接 SetScale 会让面板朝原点缩进/弹出，
    -- 重锚定为 旧偏移 × 旧scale / 新scale 抵消。
    -- ⚠️ 必须 IsShown() 守卫：本客户端隐藏框体的 GetLeft 也返回值（非 nil），
    -- 不加守卫的话登录路径（LoadSettings）会误触发补偿，把刚 SetPoint 的
    -- 偏移放大 旧scale/新scale 倍（scale 0.55 → 每次登录 ×1.82 复利膨胀，
    -- 存档 X=3391 实锤）。补偿只服务滚轮缩放路径（框体可见时）。另外
    -- LoadSettings 的 SetPoint 已移到 SetScale 之后，原值落点即存档物理位，
    -- 登录路径本就不需要补偿。
    local vOldLeft = OutfitterQuickSwapFrame:GetLeft();
    local vOldBottom = OutfitterQuickSwapFrame:GetBottom();
    local vOldScale = OutfitterQuickSwapFrame:GetScale() or 1;

    OutfitterQuickSwapFrame:SetScale(pScale);

    -- 弹出框跟随锚定分栏的比例（两分栏各自缩放，见 SyncPopupScale）
    OutfitterQuickSwap_SyncPopupScale();

    if vOldLeft and vOldBottom and OutfitterQuickSwapFrame:IsShown() then
        OutfitterQuickSwapFrame:ClearAllPoints();
        OutfitterQuickSwapFrame:SetPoint(
            "BOTTOMLEFT", "UIParent", "BOTTOMLEFT",
            vOldLeft * vOldScale / pScale, vOldBottom * vOldScale / pScale);
    end

    -- 仅在面板可见时存档：LoadSettings 在 frame 未 Show 时调 SetScale，
    -- 无条件存档会把 Enabled 覆写 false + 位置存脏（下次进服面板不显示）
    if OutfitterQuickSwapFrame:IsShown() then
        OutfitterQuickSwap_SaveSettings();
    end

    -- 百分比提示：面板左上角外显示 1s
    if OutfitterQuickSwapScaleText then
        OutfitterQuickSwapScaleText:SetText(math.floor(pScale * 100 + 0.5) .. "%");
        OutfitterQuickSwapScaleText:Show();
        gQS_ScaleTextHideAt = GetTime() + 1;
    end
end

-- 滚轮缩放回调（arg1：+1 上滚放大 / -1 下滚缩小，步进 5%）
function OutfitterQuickSwap_OnMouseWheel(pDelta)
    if gOutfitterQuickSwap_Settings.Locked then
        return; -- 锁定面板（TrinketMenu Locked）：禁止移动/缩放
    end

    OutfitterQuickSwap_SetScale((gOutfitterQuickSwap_Settings.Scale or 1) + (pDelta > 0 and 0.05 or -0.05));
end

--------------------------------------------------------------------------
-- 分栏2（饰品模式第二栏「其余部位」）：独立框体，可单独拖动/滚轮缩放/位置存档。
-- 逻辑与分栏1 同款；无标题栏，直接拖栏位条。
--------------------------------------------------------------------------

-- 分栏2 缩放（TrinketMenu.ScaleFrame 同款补偿，IsShown 守卫防登录复利膨胀——
-- 教训与 SetScale 相同：隐藏框 GetLeft 非 nil，无守卫会每次登录放大偏移）
function OutfitterQuickSwap_SetScale2(pScale)
    if not OutfitterQuickSwapFrame2 then
        return;
    end

    pScale = math.min(2, math.max(0.5, math.floor(pScale * 100 + 0.5) / 100));
    gOutfitterQuickSwap_Settings.Scale2 = pScale;

    local vOldLeft = OutfitterQuickSwapFrame2:GetLeft();
    local vOldBottom = OutfitterQuickSwapFrame2:GetBottom();
    local vOldScale = OutfitterQuickSwapFrame2:GetScale() or 1;

    OutfitterQuickSwapFrame2:SetScale(pScale);

    OutfitterQuickSwap_SyncPopupScale();

    if vOldLeft and vOldBottom and OutfitterQuickSwapFrame2:IsShown() then
        OutfitterQuickSwapFrame2:ClearAllPoints();
        OutfitterQuickSwapFrame2:SetPoint(
            "BOTTOMLEFT", "UIParent", "BOTTOMLEFT",
            vOldLeft * vOldScale / pScale, vOldBottom * vOldScale / pScale);
    end

    if OutfitterQuickSwapFrame2:IsShown() then
        OutfitterQuickSwap_SaveSettings();
    end
end

-- 分栏2 滚轮缩放回调
function OutfitterQuickSwap_OnMouseWheel2(pDelta)
    if gOutfitterQuickSwap_Settings.Locked then
        return;
    end

    OutfitterQuickSwap_SetScale2((gOutfitterQuickSwap_Settings.Scale2 or 1) + (pDelta > 0 and 0.05 or -0.05));
end

-- 分栏2 拖拽结束后重锚 BOTTOMLEFT（与 ReanchorFrame 同理：StopMovingOrSizing 留
-- TOPLEFT 锚会让 SetHeight 伸缩时跳位）
function OutfitterQuickSwap_ReanchorFrame2()
    if not OutfitterQuickSwapFrame2 then
        return;
    end

    local vLeft, vBottom = OutfitterQuickSwapFrame2:GetLeft(), OutfitterQuickSwapFrame2:GetBottom();

    if not vLeft or not vBottom then
        return;
    end

    -- 拖动 = 用户接管位置：置标记后 SaveSettings 才持久化 X2/Y2
    gQS_Frame2Moved = true;
    OutfitterQuickSwapFrame2:ClearAllPoints();
    OutfitterQuickSwapFrame2:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", vLeft, vBottom);
end

-- 分栏2 默认锚定：贴在分栏1 正下方（相对锚定，随分栏1 移动；用户拖动/缩放
-- 分栏2 后由 gQS_Frame2Moved 标记转为绝对坐标存档）。
-- 分栏1 本身贴着屏幕底边时正下方会整个顶出屏幕外（实测"分栏2 看不到了"），
-- 此时改为锚定到分栏1 上方
function OutfitterQuickSwap_DefaultFrame2Anchor(pRows)
    if not OutfitterQuickSwapFrame2 or not OutfitterQuickSwapFrame then
        return;
    end

    -- 预估分栏2 所需高度：pRows 行格子 + 底距 8 + 顶缝/标题 38 + 余量（按大算防裁切）
    local vRows = math.max(1, pRows or 1);
    local vGap = pfUI and 4 or 0;
    local vNeed = vRows * (gQS_CellSize + vGap) + 8 + 38 + 16;
    local vBaseBottom = OutfitterQuickSwapFrame:GetBottom();

    OutfitterQuickSwapFrame2:ClearAllPoints();

    if vBaseBottom and (vBaseBottom - 6 - vNeed) < 0 then
        -- 下方放不下：放分栏1 正上方（同样相对锚定跟随）
        OutfitterQuickSwapFrame2:SetPoint("BOTTOMLEFT", "OutfitterQuickSwapFrame", "TOPLEFT", 0, 6);
    else
        OutfitterQuickSwapFrame2:SetPoint("TOPLEFT", "OutfitterQuickSwapFrame", "BOTTOMLEFT", 0, -6);
    end
end

--------------------------------------------------------------------------
-- 面板右键菜单（TrinketMenu 同款功能：锁定）
-- 入口：栏位条/标题栏右键。停止排队是按部位的：装备槽 Alt+右键切换该部位
--------------------------------------------------------------------------

-- 菜单项构建（1.12 UIDropDownMenu：普通 info 表 + AddButton(info, level)，
-- pfUI/modules/loot.lua 同款用法；checked + isNotRadio = 勾选样式开关项）
function OutfitterQuickSwap_MenuInit()
    local vInfo;

    vInfo = {};
    vInfo.text = "自动排队设置…";
    vInfo.func = function()
        OutfitterQuickSwap_OpenQueueCfg();
    end;
    UIDropDownMenu_AddButton(vInfo, 1);

    vInfo = {};
    vInfo.text = "锁定面板（禁止拖动/缩放）";
    vInfo.checked = gOutfitterQuickSwap_Settings.Locked and 1 or nil;
    vInfo.isNotRadio = 1;
    vInfo.func = function()
        gOutfitterQuickSwap_Settings.Locked = not gOutfitterQuickSwap_Settings.Locked;
        OutfitterQuickSwap_SaveSettings();
        -- 边框随固定模式切换（TrinketMenu.ReflectLock 同款：锁定=透明，解锁=显示）
        OutfitterQuickSwap_ApplyPanelStyle();
    end;
    UIDropDownMenu_AddButton(vInfo, 1);

    -- 备选框常显（TrinketMenu KeepOpen「保持列表开启」同款）
    vInfo = {};
    vInfo.text = "备选框常显（弹出后不自动收起）";
    vInfo.checked = gOutfitterQuickSwap_Settings.PopupAlways and 1 or nil;
    vInfo.isNotRadio = 1;
    vInfo.func = function()
        gOutfitterQuickSwap_Settings.PopupAlways = not gOutfitterQuickSwap_Settings.PopupAlways;
        OutfitterQuickSwap_SaveSettings();
        OutfitterQuickSwap_Message(gOutfitterQuickSwap_Settings.PopupAlways
            and "备选框常显：开启（弹出列表不再自动收起）"
            or "备选框常显：关闭（鼠标移开 0.75s 后自动收起）");
    end;
    UIDropDownMenu_AddButton(vInfo, 1);

    -- 饰品模式（分类双栏）：饰品1/饰品2/圣物栏与其余部位分开显示
    vInfo = {};
    vInfo.text = "饰品模式（饰品组与其余部位分开）";
    vInfo.checked = gOutfitterQuickSwap_Settings.TrinketMode and 1 or nil;
    vInfo.isNotRadio = 1;
    vInfo.func = function()
        gOutfitterQuickSwap_Settings.TrinketMode = not gOutfitterQuickSwap_Settings.TrinketMode;
        OutfitterQuickSwap_SaveSettings();
        OutfitterQuickSwap_RebuildBar();
        OutfitterQuickSwap_Message(gOutfitterQuickSwap_Settings.TrinketMode
            and "饰品模式：开启（饰品1/饰品2/圣物栏单独一组，与其余部位分开两栏；备选列表左键换上格、右键换下格）"
            or "饰品模式：关闭（恢复单栏按勾选部位显示）");
    end;
    UIDropDownMenu_AddButton(vInfo, 1);

    -- 竖向排列（false = 横向，默认）
    vInfo = {};
    vInfo.text = "竖向排列（切换横/竖）";
    vInfo.checked = gOutfitterQuickSwap_Settings.Vertical and 1 or nil;
    vInfo.isNotRadio = 1;
    vInfo.func = function()
        gOutfitterQuickSwap_Settings.Vertical = not gOutfitterQuickSwap_Settings.Vertical;
        OutfitterQuickSwap_SaveSettings();
        OutfitterQuickSwap_RebuildBar();
        OutfitterQuickSwap_Message(gOutfitterQuickSwap_Settings.Vertical
            and "排列方向：竖向（饰品模式下饰品组在左列）"
            or "排列方向：横向（饰品模式下饰品组在上行）");
    end;
    UIDropDownMenu_AddButton(vInfo, 1);
end

-- 在光标处弹出菜单（1.12：ToggleDropDownMenu(level, value, frame, anchor, x, y)）
function OutfitterQuickSwap_ToggleMenu()
    if not OutfitterQuickSwapDropDown then
        return;
    end

    CloseDropDownMenus();
    ToggleDropDownMenu(1, nil, OutfitterQuickSwapDropDown, "cursor", 0, 0);
end

--------------------------------------------------------------------------
-- 首个饰品自动弹出（TrinketMenu 逻辑：TrinketMenu.lua:311 登录时已穿戴饰品
-- 才显示主框；本插件扩展为游戏中首次穿戴上饰品也自动弹出，仅一次）
--------------------------------------------------------------------------

-- 已穿戴饰品（TrinketMenu 判定同款：饰品槽 13 / 14 任一有物品）
function OutfitterQuickSwap_HasTrinket()
    return GetInventoryItemLink("player", 13) ~= nil
        or GetInventoryItemLink("player", 14) ~= nil;
end

-- 仅在 AutoShown 标记未置位时生效一次；用户之后手动关闭不会再被弹出
function OutfitterQuickSwap_CheckFirstTrinket()
    if gOutfitterQuickSwap_Settings.AutoShown then
        return;
    end

    if OutfitterQuickSwap_HasTrinket() then
        gOutfitterQuickSwap_Settings.AutoShown = true;

        if not OutfitterQuickSwapFrame:IsShown() then
            -- 保险：确保精简样式（隐藏标题栏/关闭按钮/背景）在显示前已应用，
            -- 覆盖新角色无存档等 ApplyPanelStyle 可能未执行的路径
            OutfitterQuickSwap_ApplyPanelStyle();
            OutfitterQuickSwapFrame:Show();
            OutfitterQuickSwap_SaveSettings();
        end
    end
end

--------------------------------------------------------------------------
-- 栏位条（显示已穿戴装备）
--------------------------------------------------------------------------

-- 冷却框创建类型：1.12 的 CooldownFrameTemplate 是 Model 模板（扫盘动画靠 Model 的
-- SetSequence/AdvanceTime），必须按 Model 创建（pfUI compat/vanilla.lua 的
-- COOLDOWN_FRAME_TYPE="Model"，TrinketMenu 的 ActionButtonTemplate 内置冷却框同为
-- Model）。用 "Frame" 创建时 pfUI/OmniCC 等外部冷却文字钩子不会接管此帧。
OutfitterQuickSwap_cCooldownFrameType = COOLDOWN_FRAME_TYPE or "Model";

-- 共用冷却框 + 倒计时文字（栏位按钮/弹出网格按钮同款，TrinketMenu 结构）：
-- 文字放按钮底部一条（TrinketMenuTimeTemplate 同款位置），不遮挡外部插件居中的数字
function OutfitterQuickSwap_SetupCooldownFrame(pButton)
    local vName = pButton:GetName() .. "Cooldown";
    local vOK, vCooldown = pcall(CreateFrame, OutfitterQuickSwap_cCooldownFrameType, vName, pButton, "CooldownFrameTemplate");

    if not vOK or not vCooldown then
        -- 兜底：个别环境按 Frame 也能工作
        vOK, vCooldown = pcall(CreateFrame, "Frame", vName, pButton, "CooldownFrameTemplate");
    end

    if vOK and vCooldown then
        vCooldown:SetAllPoints();
        vCooldown:SetFrameLevel(pButton:GetFrameLevel() + 1);
        pButton.Cooldown = vCooldown;
    end

    local vCdText = pButton:CreateFontString(pButton:GetName() .. "CooldownText", "OVERLAY", "GameFontNormalSmall");
    vCdText:SetPoint("BOTTOMRIGHT", pButton, "BOTTOMRIGHT", 0, 1);
    vCdText:SetPoint("BOTTOMLEFT", pButton, "BOTTOMLEFT", 0, 1);
    pButton.CooldownText = vCdText;
end

-- pfUI 环境下的按钮美化（TrinketMenu 皮肤同款 = addonskinner 的 SkinActionButton）：
-- 图标满铺微缩（TexCoord .08 内缩），高亮贴图同比例，深色细边框 backdrop
-- （CreateBackdrop 非 legacy，画在子 frame 上）。经典 UI-Quickslot2 边框环若已
-- 存在则隐藏（.Border 引用保留，品质色辅助函数对 nil 安全）。品质色改染到
-- backdrop 边框上（SetBorderColor）。按钮懒创建，本函数在创建期调用即生效，
-- 早于 pfUI 加载创建的按钮由 pfui-skin.lua 兜底补皮。
function OutfitterQuickSwap_SkinButtonPFUI(pButton)
    if not pfUI or not pfUI.api or pButton.backdrop then
        return;
    end

    local vIcon = pButton.Icon;

    if vIcon then
        vIcon:SetAllPoints(pButton);
        vIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
    end

    local vHighlight = pButton.GetHighlightTexture and pButton:GetHighlightTexture();

    if vHighlight then
        vHighlight:SetAllPoints(pButton);
        vHighlight:SetTexCoord(0.08, 0.92, 0.08, 0.92);
    end

    if pButton.Border then
        pButton.Border:Hide();
    end

    pcall(pfUI.api.CreateBackdrop, pButton);
end

-- 品质色着色入口：经典边框环走 SetVertexColor；pfUI 模式染 backdrop 边框
function OutfitterQuickSwap_SetBorderColor(pButton, pR, pG, pB)
    if pButton.Border then
        pButton.Border:SetVertexColor(pR, pG, pB, 1);
    end

    if pButton.backdrop then
        pButton.backdrop:SetBackdropBorderColor(pR, pG, pB, 1);
    end
end

-- 覆盖式边框环（TrinketMenu/ActionButtonTemplate 同款手法）：边框是叠在图标边缘
-- 上的一圈贴图，图标满铺整个按钮。不用 backdrop 花边框——厚边框画在图标四周会
-- 把图标挤小、视觉尺寸和间隙都撑大。pfUI 环境走 SkinButtonPFUI（深色细边框，
-- 与 TrinketMenu 在 pfUI 下的观感一致），无 pfUI 回退经典动作条边框环
-- UI-Quickslot2。品质色统一走 SetBorderColor 着色。
function OutfitterQuickSwap_CreateBorder(pButton)
    if pfUI and pfUI.api then
        OutfitterQuickSwap_SkinButtonPFUI(pButton);
        return;
    end

    local vTexture = "Interface\\Buttons\\UI-Quickslot2";
    local vOutset = 11;   -- UI-Quickslot2 标准 58x58（36px 按钮 + 两侧外扩 11px）

    local vBorder = pButton:CreateTexture(pButton:GetName() .. "Border", "BORDER");
    vBorder:SetTexture(vTexture);
    vBorder:SetPoint("TOPLEFT", pButton, "TOPLEFT", -vOutset, vOutset);
    vBorder:SetPoint("BOTTOMRIGHT", pButton, "BOTTOMRIGHT", vOutset, -vOutset);
    pButton.Border = vBorder;
end

function OutfitterQuickSwap_GetSlotButtonEx(pParent, pIndex)
    local vButton = gQS_SlotButtons[pIndex];

    if not vButton then
        vButton = CreateFrame("Button", "OutfitterQuickSwapSlot" .. pIndex, pParent);
        vButton:SetWidth(gQS_CellSize);
        vButton:SetHeight(gQS_CellSize);
        vButton:SetFrameLevel(pParent:GetFrameLevel() + 2);

        local vIcon = vButton:CreateTexture(vButton:GetName() .. "Icon", "BACKGROUND");
        vIcon:SetAllPoints();
        vButton.Icon = vIcon;

        -- 冷却转盘 + 倒计时文字（Model 型冷却框，pfUI/OmniCC 可接管）
        OutfitterQuickSwap_SetupCooldownFrame(vButton);

        -- 排队角标（战斗中排队待换的物品小图标，TrinketMenu.UpdateCombatQueue 模式）
        local vQueueIcon = vButton:CreateTexture(vButton:GetName() .. "Queue", "OVERLAY");
        vQueueIcon:SetWidth(14);
        vQueueIcon:SetHeight(14);
        vQueueIcon:SetPoint("BOTTOMRIGHT", vButton, "BOTTOMRIGHT", -1, 1);
        vButton.QueueIcon = vQueueIcon;
        vQueueIcon:Hide();

        -- 按键绑定文字（TrinketMenu ShowHotKeys 同款：开时显示该部位的绑定键）
        local vHotKey = vButton:CreateFontString(vButton:GetName() .. "HotKey", "OVERLAY", "NumberFontNormalSmallGray");
        vHotKey:SetWidth(gQS_CellSize - 2);
        vHotKey:SetHeight(10);
        vHotKey:SetPoint("TOPRIGHT", vButton, "TOPRIGHT", -1, -2);
        vHotKey:SetJustifyH("RIGHT");
        vHotKey:SetText("");

        -- 兜底：字体模板不存在时（GetFont 返回 nil）手动设小号描边字体，避免文字不显示
        if not vHotKey:GetFont() then
            vHotKey:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE");
            vHotKey:SetTextColor(0.8, 0.8, 0.8);
        end

        vButton.HotKey = vHotKey;

        vButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square");

        -- 覆盖式边框环（TrinketMenu 同款，图标满铺 + 边框叠在图标边缘）
        OutfitterQuickSwap_CreateBorder(vButton);

        vButton:RegisterForClicks("LeftButtonUp", "RightButtonUp");

        vButton:SetScript("OnClick", function()
            OutfitterQuickSwap_SlotOnClick(this, arg1);
        end);

        vButton:SetScript("OnEnter", function()
            OutfitterQuickSwap_SlotOnEnter(this);
        end);

        vButton:SetScript("OnLeave", function()
            OutfitterQuickSwap_ClearTooltip();
        end);

        gQS_SlotButtons[pIndex] = vButton;
    end

    return vButton;
end

-- 兼容入口：分栏1 的按钮
function OutfitterQuickSwap_GetSlotButton(pIndex)
    return OutfitterQuickSwap_GetSlotButtonEx(OutfitterQuickSwapFrame, pIndex);
end

function OutfitterQuickSwap_SlotOnClick(pButton, pMouseButton)
    local vSlotName = pButton.Slot;
    if not vSlotName then
        return;
    end

    -- Shift+左键：把已装备物品链接插入聊天输入框（TrinketMenu.MainTrinket_OnClick 同款）
    if pMouseButton == "LeftButton" and IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Insert(GetInventoryItemLink("player", GetInventorySlotInfo(vSlotName)));
        return;
    end

    -- Alt+左键：把当前已穿戴的装备加入/移出该部位的自动排队（TrinketMenu Alt+点身上饰品同款）。
    -- 栏位按钮显示的是"已穿戴"物品，与弹出列表的 Alt+左键（排队背包物品）是同一语义的两个入口：
    -- 这里排的是身上这件，换装轮换后它会按队列顺序自动换回来。
    if pMouseButton == "LeftButton" and IsAltKeyDown() then
        local vSlotID = GetInventorySlotInfo(vSlotName);
        local vLink = GetInventoryItemLink("player", vSlotID);
        local vName = vLink and string.match(vLink, "%[(.-)%]");

        if vName then
            local vAdded = OutfitterQuickSwap_ToggleQueueItem(vSlotName, vName);
            OutfitterQuickSwap_UpdateQueueMark(vSlotName);
            OutfitterQuickSwap_Message(vAdded and ("已加入自动排队：" .. vName) or ("已移出自动排队：" .. vName));
        end

        return;
    end

    if pMouseButton == "RightButton" then
        -- Alt+右键：切换该部位的自动排队暂停（TrinketMenu.SetQueue(which,"PAUSE")
        -- 按菜单粒度同款：只停这一个部位，其他部位排队照常）
        if IsAltKeyDown() then
            local vPaused = not gOutfitterQuickSwap_Settings.PausedSlots[vSlotName];
            gOutfitterQuickSwap_Settings.PausedSlots[vSlotName] = vPaused and true or nil;
            OutfitterQuickSwap_SaveSettings();
            OutfitterQuickSwap_UpdateQueueMark(vSlotName);
            OutfitterQuickSwap_Message(vSlotName .. (vPaused and " 排队已暂停" or " 排队已恢复"));
            return;
        end

        -- 右键：弹出同类装备列表（再次右键同部位则收起）
        if gQS_PopupSlot == vSlotName and OutfitterQuickSwapPopup:IsShown() then
            OutfitterQuickSwapPopup:Hide();
            gQS_PopupOwner = nil;
            gQS_HideAt = nil;
        else
            local vOK, vErr = pcall(OutfitterQuickSwap_OpenPopup, vSlotName, pButton);

            if not vOK then
                OutfitterQuickSwap_Message("弹出列表失败: " .. tostring(vErr));
            end

            gQS_PopupOwner = pButton;
            gQS_HideAt = nil;
        end
    else
        -- 左键：使用已穿戴的装备（饰品等主动物品生效）
        local vSlotID = GetInventorySlotInfo(vSlotName);

        if GetInventoryItemTexture("player", vSlotID) then
            UseInventoryItem(vSlotID);
        end
    end
end

function OutfitterQuickSwap_SlotOnEnter(pButton)
    if not pButton.Slot then
        return;
    end

    local vSlotID = GetInventorySlotInfo(pButton.Slot);

    -- tooltip（TrinketMenu.WornTrinketTooltip 模式：登记状态后定时刷新，冷却实时走秒）
    if GetInventoryItemTexture("player", vSlotID) then
        OutfitterQuickSwap_ShowItemTooltip("INVENTORY", pButton, nil, vSlotID);
    else
        -- 空槽显示部位名（无定时刷新）
        OutfitterQuickSwap_ClearTooltip();
        OutfitterQuickSwap_AnchorTooltip(pButton);

        for _, vSlot in OutfitterQuickSwap_cSlots do
            if vSlot.Slot == pButton.Slot then
                GameTooltip:SetText(vSlot.Label, 1, 1, 1);
                break;
            end
        end

        GameTooltip:Show();
    end

    -- 悬停即弹出同类装备列表（TrinketMenu 模式）
    if gQS_PopupSlot ~= pButton.Slot or not OutfitterQuickSwapPopup:IsShown() then
        local vOK, vErr = pcall(OutfitterQuickSwap_OpenPopup, pButton.Slot, pButton);

        if not vOK then
            OutfitterQuickSwap_Message("弹出列表失败: " .. tostring(vErr));
        end
    else
        gQS_PopupOwner = pButton;
    end

    gQS_HideAt = nil;
end

-- 刷新栏位按钮的图标/品质边框/冷却
function OutfitterQuickSwap_UpdateSlotButton(pButton)
    local vSlotID = GetInventorySlotInfo(pButton.Slot);
    local vTexture = GetInventoryItemTexture("player", vSlotID);

    if vTexture then
        pButton.Icon:SetTexture(vTexture);
        pButton.Icon:Show();
        pcall(pButton.Icon.SetDesaturated, pButton.Icon, 0);

        local vQuality = GetInventoryItemQuality("player", vSlotID);
        local vR, vG, vB = 0.6, 0.6, 0.6;

        if vQuality then
            local vOK, vQR, vQG, vQB = pcall(GetItemQualityColor, vQuality);
            if vOK then
                vR, vG, vB = vQR, vQG, vQB;
            end
        end

        OutfitterQuickSwap_SetBorderColor(pButton, vR, vG, vB);

        OutfitterQuickSwap_SetCooldownDisplay(pButton, GetInventoryItemCooldown("player", vSlotID));
    else
        pButton.Icon:SetTexture(nil);
        pButton.Icon:Hide();
        OutfitterQuickSwap_SetBorderColor(pButton, 0.5, 0.5, 0.5);

        OutfitterQuickSwap_SetCooldownDisplay(pButton, 0, 0);
    end
end

-- 判定物品链接是否圣物（INVTYPE_RELIC）：true=是 / nil=未知(物品数据未缓存) / false=不是。
-- 本客户端 GetItemInfo 缺 reqLevel、equipLoc 索引整体前移（不可硬编索引），
-- 扫描全部返回值找 ^INVTYPE_ 串；pcall 包裹 + 只在数据完整时判定（防缓存污染）
function OutfitterQuickSwap_IsRelicLink(pLink)
    if not pLink or not string.find(pLink, "item:") then
        return false;
    end

    local vOK, v1, v2, v3, v4, v5, v6, v7, v8, v9 = pcall(GetItemInfo, pLink);

    if not vOK or not v1 then
        return nil; -- 物品未缓存：未知，由调用方兜底
    end

    for _, v in { v1, v2, v3, v4, v5, v6, v7, v8, v9 } do
        if type(v) == "string" and string.find(v, "^INVTYPE_") then
            return v == "INVTYPE_RELIC" and true or false;
        end
    end

    return nil;
end

-- 玩家当前是否持有圣物：装备位 18（远程/圣物栏）为圣物，或背包中存在圣物。
-- 返回 true / nil（nil=无法确定，按职业兜底显示，不缓存否定结果）
function OutfitterQuickSwap_HasRelicItem()
    -- 先看装备位 18
    local vLink = GetInventoryItemLink("player", 18);

    if vLink then
        local vRelic = OutfitterQuickSwap_IsRelicLink(vLink);

        if vRelic ~= nil then
            return vRelic;
        end

        -- 物品数据未缓存：按职业兜底（骑士/萨满/德鲁伊的远程栏只放圣物）
        local _, vClass = UnitClass("player");
        return (vClass == "PALADIN" or vClass == "SHAMAN" or vClass == "DRUID") and true or nil;
    end

    -- 装备位空：扫背包找圣物
    for vBag = 0, 4 do
        local vNum = GetContainerNumSlots(vBag);

        for vSlot = 1, vNum do
            local vBagLink = GetContainerItemLink(vBag, vSlot);

            if vBagLink and OutfitterQuickSwap_IsRelicLink(vBagLink) then
                return true;
            end
        end
    end

    return nil;
end

-- 圣物获得/用尽 → 饰品模式圣物栏显隐联动重建。
-- 只在显隐状态翻转时重建（gQS_TrinketRelicState 由 RebuildBar 每次写入），
-- BAG_UPDATE 高频触发也安全
function OutfitterQuickSwap_CheckRelicVisibility()
    if not gOutfitterQuickSwap_Settings.TrinketMode
        or not OutfitterQuickSwapFrame or not OutfitterQuickSwapFrame:IsShown() then
        return;
    end

    local vState = OutfitterQuickSwap_HasRelicItem() and true or false;

    if vState ~= gQS_TrinketRelicState then
        OutfitterQuickSwap_RebuildBar();
    end
end

-- 按勾选重建栏位条。
-- 饰品模式（TrinketMode）= 分类双栏：饰品1/饰品2/圣物栏为一组（TrinketMenu 主框
-- 三按钮 id 13/14/18 同款，TrinketMenu.xml:164-188），其余勾选部位为另一组，两组
-- 分属两个独立框体（分栏1/分栏2），可各自拖动、滚轮缩放、位置缩放独立存档——
-- 横向排列时各占一行（饰品组在上）、竖向排列时各占一列（饰品组在左）。
-- 圣物栏限定（TrinketMenu.lua:303-304 HasRelic 同款）：仅骑士/萨满/德鲁伊显示，
-- 且实际持有圣物（装备位与背包均无圣物时隐藏远程栏，BAG_UPDATE 翻转时联动重建）。
function OutfitterQuickSwap_RebuildBar()
    if not OutfitterQuickSwapFrame then
        return;
    end

    -- 组装显示分组：vTrinketGroup = 饰品组（饰品模式专属，不受部位勾选影响）；
    -- vMainGroup = 主组（勾选的部位；饰品模式下剔除饰品组三个槽位）
    local vTrinketGroup = {};
    local vMainGroup = {};

    if gOutfitterQuickSwap_Settings.TrinketMode then
        local _, vClass = UnitClass("player");
        -- 职业限定（TrinketMenu.lua:303-304 HasRelic 同款）+ 持有判定：
        -- 没有圣物（装备位和背包都没有）就不显示远程栏
        local vHasRelic = false;

        if vClass == "PALADIN" or vClass == "SHAMAN" or vClass == "DRUID" then
            vHasRelic = OutfitterQuickSwap_HasRelicItem() and true or false;
        end

        gQS_TrinketRelicState = vHasRelic;

        for _, vSlot in OutfitterQuickSwap_cSlots do
            if vSlot.Slot == "Trinket0Slot" or vSlot.Slot == "Trinket1Slot"
                or (vSlot.Slot == "RangedSlot" and vHasRelic) then
                table.insert(vTrinketGroup, vSlot);
            elseif gOutfitterQuickSwap_EnabledSlots[vSlot.Slot] then
                table.insert(vMainGroup, vSlot);
            end
        end
    else
        for _, vSlot in OutfitterQuickSwap_cSlots do
            if gOutfitterQuickSwap_EnabledSlots[vSlot.Slot] then
                table.insert(vMainGroup, vSlot);
            end
        end
    end

    -- 放置：饰品模式两组分属两个独立框体（各自可拖动/缩放/位置存档）；
    -- 非饰品模式全部在分栏1。组内横向=单行、竖向=单列。
    -- 按钮池两分栏共用（gQS_SlotButtons 顺序编号，SetParent 换父，名字保持唯一）
    local vVertical = gOutfitterQuickSwap_Settings.Vertical;
    local vBarGap = pfUI and 4 or gQS_CellGap;
    local vCount = 0;
    local vN1, vN2 = 0, 0;

    local vPlace = function(pGroup, pFrame, pBar)
        local n = table.getn(pGroup);

        for vK = 1, n do
            vCount = vCount + 1;

            local vButton = OutfitterQuickSwap_GetSlotButtonEx(pFrame, vCount);
            vButton.Slot = pGroup[vK].Slot;

            local vRow, vCol;

            if vVertical then
                vRow = vK - 1;
                vCol = 0;
            else
                vRow = 0;
                vCol = vK - 1;
            end

            vButton:SetParent(pFrame);
            vButton:SetFrameLevel(pFrame:GetFrameLevel() + 2);
            vButton:ClearAllPoints();
            vButton:SetPoint(
                "TOPLEFT",
                pBar,
                "TOPLEFT",
                vCol * (gQS_CellSize + vBarGap) + 2,
                -(vRow * (gQS_CellSize + vBarGap))
            );

            OutfitterQuickSwap_UpdateSlotButton(vButton);
            vButton:Show();
        end

        return n;
    end;

    if gOutfitterQuickSwap_Settings.TrinketMode and OutfitterQuickSwapFrame2 and OutfitterQuickSwapBar2 then
        vN1 = vPlace(vTrinketGroup, OutfitterQuickSwapFrame, OutfitterQuickSwapBar);
        vN2 = vPlace(vMainGroup, OutfitterQuickSwapFrame2, OutfitterQuickSwapBar2);
    else
        vN1 = vPlace(vMainGroup, OutfitterQuickSwapFrame, OutfitterQuickSwapBar);
    end

    -- 隐藏多余按钮（整池）
    for vIndex = vCount + 1, table.getn(gQS_SlotButtons) do
        gQS_SlotButtons[vIndex].Slot = nil;
        gQS_SlotButtons[vIndex]:Hide();
    end

    -- 每个分栏按自己的格子数收缩/撑开（横向=1 行 N 列；竖向=N 行 1 列）
    if vVertical then
        OutfitterQuickSwap_ApplyLayout(OutfitterQuickSwapFrame, OutfitterQuickSwapBar, math.max(1, vN1), 1);
    else
        OutfitterQuickSwap_ApplyLayout(OutfitterQuickSwapFrame, OutfitterQuickSwapBar, 1, math.max(1, vN1));
    end

    if OutfitterQuickSwapFrame2 then
        if vVertical then
            OutfitterQuickSwap_ApplyLayout(OutfitterQuickSwapFrame2, OutfitterQuickSwapBar2, math.max(1, vN2), 1);
        else
            OutfitterQuickSwap_ApplyLayout(OutfitterQuickSwapFrame2, OutfitterQuickSwapBar2, 1, math.max(1, vN2));
        end

        -- 分栏2 显隐：饰品模式 + 主组非空 + 主框显示时才出现
        if gOutfitterQuickSwap_Settings.TrinketMode and vN2 > 0 and OutfitterQuickSwapFrame:IsShown() then
            if not gQS_Frame2Moved then
                -- 未接管：按本次实际行数重估上/下方落点（竖排时分栏很高，登录时按
                -- 单行预估会低估高度，仍可能顶出屏幕底）
                OutfitterQuickSwap_DefaultFrame2Anchor(vVertical and vN2 or 1);
            end
            OutfitterQuickSwapFrame2:Show();
        else
            OutfitterQuickSwapFrame2:Hide();
        end
    end

    OutfitterQuickSwap_RefreshEmptyHint(vN1);
    OutfitterQuickSwap_RefreshQueueMarks();
    OutfitterQuickSwap_ReflectKeyBindings();
end

function OutfitterQuickSwap_RefreshEmptyHint(pCount)
    if pCount == 0 and not gOutfitterQuickSwap_Settings.Compact then
        OutfitterQuickSwapEmptyText:SetText("在 Outfitter「快捷换装」页勾选要显示的部位");
        OutfitterQuickSwapEmptyText:Show();
    else
        OutfitterQuickSwapEmptyText:Hide();
    end
end

-- 应用面板样式（精简模式 = 只显示装备，TrinketMenu 同款）
function OutfitterQuickSwap_ApplyPanelStyle()
    if not OutfitterQuickSwapFrame then
        return;
    end

    -- 背景显隐：有 pfUI backdrop（pfui-skin.lua 创建）时切换其显隐，
    -- 否则走 TrinketMenu 式经典边框（bgFile=UI-DialogBox-Background + tooltip 边框，
    -- TrinketMenu.xml:110 同款；配色照抄 TrinketMenu.ReflectLock：
    --   解锁 c=0.5 → 石纹背景与边框半透明可见，提示"可抓取拖动/滚轮缩放"；
    --   锁定 c=0   → 背景边框全透明（固定模式，外观更干净），拖动/缩放同步被禁）
    -- ⚠️ 仅普通模式显示背景框；精简模式永远透明（用户实测：精简+边框观感差）
    local vBackdrop = OutfitterQuickSwapFrame.backdrop;

    -- TrinketMenu.ReflectLock 配色（TrinketMenuOpt.lua:172-178）
    local vLockTint = gOutfitterQuickSwap_Settings.Locked and 0 or 0.5;

    if gOutfitterQuickSwap_Settings.Compact then
        OutfitterQuickSwapTitleBar:Hide();
        OutfitterQuickSwapClose:Hide();
        OutfitterQuickSwapEmptyText:Hide();
        if vBackdrop then
            vBackdrop:Hide();
        else
            OutfitterQuickSwapFrame:SetBackdropColor(0, 0, 0, 0);
            OutfitterQuickSwapFrame:SetBackdropBorderColor(0, 0, 0, 0);
        end
    else
        OutfitterQuickSwapTitleBar:Show();
        OutfitterQuickSwapClose:Show();
        if vBackdrop then
            vBackdrop:Show();
        else
            -- 普通模式标题栏需要背景衬托：边框常显，仅背景随固定模式降透明度
            OutfitterQuickSwapFrame:SetBackdropColor(vLockTint, vLockTint, vLockTint, vLockTint);
            OutfitterQuickSwapFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1);
        end
    end

    -- 分栏2（饰品模式第二栏）：无标题栏，配色规则与分栏1 相同——
    -- 有 pfUI backdrop（pfui-skin.lua 创建）时切其显隐，否则走经典 SetBackdrop 路径
    if OutfitterQuickSwapFrame2 then
        local vBackdrop2 = OutfitterQuickSwapFrame2.backdrop;

        if gOutfitterQuickSwap_Settings.Compact then
            if vBackdrop2 then
                vBackdrop2:Hide();
            else
                OutfitterQuickSwapFrame2:SetBackdropColor(0, 0, 0, 0);
                OutfitterQuickSwapFrame2:SetBackdropBorderColor(0, 0, 0, 0);
            end
        else
            if vBackdrop2 then
                vBackdrop2:Show();
            else
                OutfitterQuickSwapFrame2:SetBackdropColor(vLockTint, vLockTint, vLockTint, vLockTint);
                OutfitterQuickSwapFrame2:SetBackdropBorderColor(0.5, 0.5, 0.5, 1);
            end
        end
    end

    OutfitterQuickSwap_RebuildBar();
end

-- 按栏位实际数量调整面板尺寸（单行不换行，宽度 = 部位数 × 格宽）
-- ⚠️ 布局铁律：栏位条永久锚定框体底边（见创建处），这里绝不重锚栏位条——
-- 只改框体高度（顶边伸缩）。实测本客户端切换路径中对栏位条的 SetPoint 会静默
-- 失效（条停在创建锚点上），导致模式切换时图标跟着框体顶边跳一个高度差；
-- 底边被 BOTTOMLEFT(UIParent) 锚死，锚定底边 + 只改高度 = 装备行位置与模式解耦。
-- 按行列数调整分栏框体尺寸（分栏1/分栏2 各自调用，TrinketMenu 手感）
function OutfitterQuickSwap_ApplyLayout(pFrame, pBar, pRows, pCols)
    if not pFrame or not pBar then
        return;
    end

    local vBarGap = pfUI and 4 or gQS_CellGap;
    local vRows = math.max(1, pRows or 1);
    local vCols = math.max(1, pCols or 1);
    local vBarHeight = vRows * (gQS_CellSize + vBarGap) + 6;
    local vBarWidth = vCols * (gQS_CellSize + vBarGap) + 4;

    pBar:SetHeight(vBarHeight);

    if gOutfitterQuickSwap_Settings.Compact then
        -- 精简：底距 8 + 顶缝 2（无标题区，背景隐藏顶边不可见）
        pFrame:SetHeight(vBarHeight + 10);
    else
        -- 普通：底距 8 + 标题区 30（与原 TOP-(26+4) 布局等效）
        pFrame:SetHeight(vBarHeight + 38);
    end

    pFrame:SetWidth(vBarWidth + 16);
end

--------------------------------------------------------------------------
-- 配置区（独立标签页：Outfitter 主窗口第 4 个标签「快捷换装」）
--------------------------------------------------------------------------

function OutfitterQuickSwap_OnConfigClick()
    -- 勾选立即生效并保存（this.Slot 在创建时已赋值）
    local vSlot = this.Slot;

    if not vSlot then
        return;
    end

    gOutfitterQuickSwap_EnabledSlots[vSlot] = this:GetChecked() and true or nil;

    -- 标记"已配置"：之后即使全部取消也照原样保存，不被判为未配置回弹默认
    gOutfitterQuickSwap_Settings.SlotsConfigured = true;

    OutfitterQuickSwap_SaveSettings();
    OutfitterQuickSwap_RebuildBar();
end

-- pfUI 环境下的标签重排：原版链式锚点（RIGHT=前一个.LEFT+16）是斜角贴图
-- 专用的咬合式布局，pfUI SkinTab 换成方形平贴标签（OnShow 时宽度=文字宽+20）
-- 后，+16 嵌入会令相邻标签文字互相压住。这里改为按各标签实际宽度沿窗口
-- 底部等间隙均匀分布（边缘留距 = 标签间隙）。非 pfUI 环境直接返回，
-- 原版布局零影响。
function OutfitterQuickSwap_FixTabLayout()
    if not pfUI or not OutfitterFrame then
        return;
    end

    local vTabs = {};
    local vTotal = 0;

    for i = 1, 4 do
        local vTab = getglobal("OutfitterFrameTab" .. i);

        if not vTab then
            return; -- 标签不齐就不处理，避免半套布局
        end

        -- 宽度与 pfUI SkinTab 的 OnShow 公式保持一致（文字宽+20），
        -- 不依赖按钮当前宽度（皮肤 OnShow 可能尚未触发过）
        vTab._qsWidth = vTab:GetTextWidth() + 20;
        vTotal = vTotal + vTab._qsWidth;
        table.insert(vTabs, vTab);
    end

    local vFrameWidth = OutfitterFrame:GetWidth() or 256;
    local vGap = (vFrameWidth - vTotal) / (table.getn(vTabs) + 1);

    if vGap < 2 then
        vGap = 2; -- 极端字体宽度下兜底，至少留 2px 间隙
    end

    -- 从最右（Tab1）向左依次独立锚到窗口底边，y 与原版链一致（-29）
    local vFromRight = vGap;

    for _, vTab in ipairs(vTabs) do
        vTab:ClearAllPoints();
        vTab:SetPoint("BOTTOMRIGHT", OutfitterFrame, "BOTTOMRIGHT", -vFromRight, -29);
        vFromRight = vFromRight + vTab._qsWidth + vGap;
    end
end

-- 创建第 4 个标签「快捷换装」+ 独立配置页（动态创建，只建一次）
function OutfitterQuickSwap_BuildOptions()
    local vOptionsFrame = getglobal("OutfitterOptionsFrame");

    if not vOptionsFrame or not getglobal("OutfitterFrameTab3") then
        return;
    end

    -- 配置页：与其他页面同父级、setAllPoints
    local vPanel = CreateFrame("Frame", "OutfitterQuickSwapPanelFrame", vOptionsFrame:GetParent());
    vPanel:SetAllPoints(vOptionsFrame:GetParent());
    vPanel:Hide();

    -- 页面大标题（与其他页同款式）
    local vPageTitle = vPanel:CreateFontString("OutfitterQuickSwapPageTitle", "OVERLAY", "GameFontNormalLarge");
    vPageTitle:SetPoint("TOP", vPanel, "TOP", 0, -25);
    vPageTitle:SetText("快捷换装");

    -- 说明行（紧贴下方部位网格上方，起"段落标题"作用）
    local vDesc = vPanel:CreateFontString("OutfitterQuickSwapPageDesc", "OVERLAY", "GameFontNormalSmall");
    vDesc:SetPoint("TOPLEFT", vPanel, "TOPLEFT", 15, -172);
    vDesc:SetText("勾选要在快捷换装栏显示的部位：");
    vDesc:SetTextColor(1, 0.82, 0.2);

    -- 面板开关区（启用 / 精简模式 / 向上弹出）
    OutfitterQuickSwap_cPanelOptions = {
        { Key = "Enabled", Label = "启用快捷换装面板" },
        { Key = "Compact", Label = "精简模式（只显示装备）" },
        { Key = "PopupUp", Label = "同类装备向上弹出" },
        { Key = "TinyTooltip", Label = "迷你提示（只显示名字/冷却）" },
        { Key = "CooldownCount", Label = "冷却计时（按钮显示剩余时间）" },
        { Key = "ShowHotKeys", Label = "显示按键（装备上显示绑定键）" },
    };

    gQS_OptionChecks = {};

    for vOptIndex, vOpt in OutfitterQuickSwap_cPanelOptions do
        local vName = "OutfitterQuickSwapOpt" .. vOpt.Key;
        local vOptCheck = getglobal(vName);

        if not vOptCheck then
            local vOK2, vFrame2 = pcall(CreateFrame, "CheckButton", vName, vPanel, "OptionsCheckButtonTemplate");

            if vOK2 and vFrame2 then
                vOptCheck = vFrame2;
                vOptCheck.Key = vOpt.Key;
                vOptCheck:SetWidth(18);
                vOptCheck:SetHeight(18);
                vOptCheck:SetHitRectInsets(-6, -140, -6, -6);

                local vText2 = getglobal(vName .. "Text");

                if vText2 then
                    vText2:SetText(vOpt.Label);
                    vText2:ClearAllPoints();
                    vText2:SetPoint("LEFT", vOptCheck, "RIGHT", 2, 0);
                    vText2:Show();
                end

                vOptCheck:SetScript("OnClick", function()
                    OutfitterQuickSwap_OnOptionClick();
                end);
            end
        end

        if vOptCheck then
            gQS_OptionChecks[vOpt.Key] = vOptCheck;
            -- 竖排（主窗口宽 256，横排放不下）；直接锚到面板顶部，填补标题下方的空档
            -- 节距 20（6 个开关）：窗口底部余量只有 14px，靠收紧节距与下方网格腾出空间
            vOptCheck:ClearAllPoints();
            vOptCheck:SetPoint("TOPLEFT", vPanel, "TOPLEFT", 15, -(46 + (vOptIndex - 1) * 20));
            vOptCheck:Show();
        end
    end

    -- 部位复选框（3 列网格，只创建一次，页面显示时刷新状态）
    for _, vSlot in OutfitterQuickSwap_cSlots do
        local vIndex = vSlot.Index;
        local vCheck = gQS_ConfigChecks[vIndex];

        if not vCheck then
            local vOK, vFrameOrErr = pcall(CreateFrame, "CheckButton", "OutfitterQuickSwapCfg" .. vIndex, vPanel, "OptionsCheckButtonTemplate");

            if not vOK then
                OutfitterQuickSwap_Message("创建配置复选框失败: " .. tostring(vFrameOrErr));
                return;
            end

            vCheck = vFrameOrErr;
            vCheck.Slot = vSlot.Slot;
            vCheck:SetWidth(18);
            vCheck:SetHeight(18);
            -- 扩大命中区：方框 + 右侧文字整块可点（pfUI 皮肤下方框视觉有偏移）
            vCheck:SetHitRectInsets(-6, -60, -6, -6);

            local vText = getglobal(vCheck:GetName() .. "Text");
            if vText then
                vText:SetText(vSlot.Short);
                vText:ClearAllPoints();
                vText:SetPoint("LEFT", vCheck, "RIGHT", 2, 0);
                vText:Show();
            end

            vCheck:SetScript("OnClick", function()
                OutfitterQuickSwap_OnConfigClick();
            end);

            gQS_ConfigChecks[vIndex] = vCheck;
        end

        local vRow = math.floor((vIndex - 1) / gQS_ConfigCols);
        local vCol = math.mod(vIndex - 1, gQS_ConfigCols);

        vCheck:ClearAllPoints();
        vCheck:SetPoint(
            "TOPLEFT",
            "OutfitterQuickSwapPageDesc",
            "BOTTOMLEFT",
            -- 列偏移 0：第一列与上方 5 个面板开关方框（x=15）完全对齐
            vCol * 84,
            -- 18：网格与说明行的间距；行距 22（原 24）—— 给第 6 个面板开关让位，
            -- 底部余量保持与旧版一致（最后一行「弹药」距窗底 ~14px）
            -(vRow * 22 + 18)
        );
    end

    -- 页面显示时同步勾选状态（存档可能在进服后才加载完）
    vPanel:SetScript("OnShow", function()
        OutfitterQuickSwap_RefreshConfigChecks();
    end);

    -- 第 4 个标签「快捷换装」（沿用 OutfitterTabTemplate，位于「设置」和「一键换装」之间）
    local vTab = getglobal("OutfitterFrameTab4");

    if not vTab then
        vTab = CreateFrame("Button", "OutfitterFrameTab4", vOptionsFrame:GetParent(), "OutfitterTabTemplate");
        vTab:SetID(4);

        local vTabText = getglobal("OutfitterFrameTab4Text");

        if vTabText then
            vTabText:SetText("快捷换装");
        else
            pcall(vTab.SetText, vTab, "快捷换装");
        end

        vTab:SetScript("OnClick", function()
            PlaySound("igMainMenuOpen");
            PanelTemplates_Tab_OnClick(OutfitterFrame);
            Outfitter_ShowPanel(OutfitterFrame.selectedTab);
        end);
    end

    -- 补齐 OnLoad 时被跳过的标签初始化：OnLoad（XML 解析期）执行时 Tab4 尚不存在，
    -- PanelTemplates_UpdateTabs 被跳过（否则崩在 UIPanelTemplates.lua:20）。
    -- 现在 4 个标签都齐了，安全地同步 numTabs 并刷新一次标签状态。
    if OutfitterFrame and PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(OutfitterFrame, 4);

        if OutfitterFrame.selectedTab then
            pcall(PanelTemplates_UpdateTabs, OutfitterFrame);
        end
    end

    -- 标签布局走 Outfitter 原版链式锚点（非 pfUI 环境的正确布局）；
    -- pfUI 环境下由 FixTabLayout 覆盖为底部均匀分布（pfUI 加载晚于本插件，
    -- 建页时多半还没就绪，所以此处调用通常空转，真正生效在进服事件）。
    local vTab3 = getglobal("OutfitterFrameTab3");

    if vTab3 then
        vTab:ClearAllPoints();
        vTab:SetPoint("RIGHT", vTab3, "LEFT", 16, 0);
    end

    local vTab1 = getglobal("OutfitterFrameTab1");

    if vTab1 then
        vTab1:SetPoint("BOTTOMRIGHT", "OutfitterFrame", "BOTTOMRIGHT", 15, -29);
    end

    OutfitterQuickSwap_FixTabLayout();
end

-- 面板开关（启用/精简/向上弹出）点击处理
function OutfitterQuickSwap_OnOptionClick()
    local vKey = this.Key;

    if not vKey then
        return;
    end

    gOutfitterQuickSwap_Settings[vKey] = this:GetChecked() and true or false;
    OutfitterQuickSwap_SaveSettings();

    if vKey == "Enabled" then
        if gOutfitterQuickSwap_Settings.Enabled then
            OutfitterQuickSwapFrame:Show();
        else
            OutfitterQuickSwapFrame:Hide();
        end
    elseif vKey == "Compact" then
        -- 栏位条已永久锚定框体底边（创建处）：切换模式只伸缩框体顶边（标题区显隐），
        -- 装备行屏幕位置恒定，无需任何平移补偿
        OutfitterQuickSwap_ApplyPanelStyle();
    elseif vKey == "ShowHotKeys" then
        OutfitterQuickSwap_ReflectKeyBindings();
    end
    -- PopupUp 由 OpenPopup 读取，无需即时处理
end

function OutfitterQuickSwap_RefreshConfigChecks()
    for _, vSlot in OutfitterQuickSwap_cSlots do
        local vCheck = gQS_ConfigChecks[vSlot.Index];

        if vCheck then
            vCheck:SetChecked(gOutfitterQuickSwap_EnabledSlots[vSlot.Slot] and 1 or 0);
        end
    end

    if gQS_OptionChecks then
        for vKey, vCheck in gQS_OptionChecks do
            vCheck:SetChecked(gOutfitterQuickSwap_Settings[vKey] and 1 or 0);
        end
    end
end

--------------------------------------------------------------------------
-- 右键弹出列表（同类装备，点选换装）
--------------------------------------------------------------------------

function OutfitterQuickSwap_GetGridButton(pIndex)
    local vButton = gQS_GridButtons[pIndex];

    if not vButton then
        vButton = CreateFrame("Button", "OutfitterQuickSwapItem" .. pIndex, OutfitterQuickSwapPopup);
        vButton:SetWidth(gQS_CellSize);
        vButton:SetHeight(gQS_CellSize);
        vButton:SetFrameLevel(OutfitterQuickSwapPopup:GetFrameLevel() + 2);

        local vIcon = vButton:CreateTexture(vButton:GetName() .. "Icon", "BACKGROUND");
        vIcon:SetAllPoints();
        vButton.Icon = vIcon;

        local vCount = vButton:CreateFontString(vButton:GetName() .. "Count", "OVERLAY", "NumberFontNormalSmall");
        vCount:SetPoint("BOTTOMRIGHT", vButton, "BOTTOMRIGHT", -1, 2);
        vButton.Count = vCount;

        -- 冷却转盘 + 倒计时文字（与装备栏一致，Model 型冷却框）
        OutfitterQuickSwap_SetupCooldownFrame(vButton);

        vButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square");

        -- 覆盖式边框环（与装备栏一致，TrinketMenu 同款）
        OutfitterQuickSwap_CreateBorder(vButton);

        vButton:RegisterForClicks("LeftButtonUp", "RightButtonUp");

        vButton:SetScript("OnClick", function()
            OutfitterQuickSwap_GridOnClick(this, arg1);
        end);

        vButton:SetScript("OnEnter", function()
            OutfitterQuickSwap_ItemOnEnter(this);
        end);

        vButton:SetScript("OnLeave", function()
            OutfitterQuickSwap_ClearTooltip();
        end);

        gQS_GridButtons[pIndex] = vButton;
    end

    return vButton;
end

function OutfitterQuickSwap_ItemOnEnter(pButton)
    if not pButton.Bag then
        return;
    end

    -- TrinketMenu.MenuTrinketTooltip 模式：背包物品 tooltip 走同一条定时刷新通道
    OutfitterQuickSwap_ShowItemTooltip("BAG", pButton, pButton.Bag, pButton.Slot);
end

-- 弹出网格物品点击（TrinketMenu.MenuTrinket_OnClick 模式：Shift 插链接 → 换装 → 收起）
function OutfitterQuickSwap_GridOnClick(pButton, pMouseButton)
    if not pButton.Bag then
        return;
    end

    -- Alt+右键：屏蔽 / 恢复当前物品（不影响换装流程、保留列表开启）
    if IsAltKeyDown() and pMouseButton == "RightButton" then
        if pButton.Name then
            local vNowHidden = OutfitterQuickSwap_ToggleHiddenItem(pButton.Name);

            OutfitterQuickSwap_Message((vNowHidden and "已屏蔽：" or "已恢复：") .. pButton.Name);

            -- 立即重排列表（非按下 Alt 时移除该物品；按下 Alt 时仅刷图标染灰状态）
            if gQS_PopupSlot and OutfitterQuickSwapPopup:IsShown() and gQS_PopupOwner then
                local vOK, vErr = pcall(OutfitterQuickSwap_OpenPopup, gQS_PopupSlot, gQS_PopupOwner);

                if not vOK then
                    OutfitterQuickSwap_Message("刷新弹出列表失败: " .. tostring(vErr));
                end
            end
        end

        return;
    end

    -- Shift+点击：把背包物品链接插入聊天输入框
    if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Insert(GetContainerItemLink(pButton.Bag, pButton.Slot));
        return;
    end

    -- Ctrl+左键：打开排队设置窗口（每物品延迟替换秒数，TrinketMenu Swap Delay 同款）
    if IsControlKeyDown() then
        OutfitterQuickSwap_OpenQueueCfg();
        return;
    end

    -- Alt+左键：加入/移出该部位的自动排队（TrinketMenu Alt+点饰品同款），不换装不收起
    if IsAltKeyDown() then
        local vLink = GetContainerItemLink(pButton.Bag, pButton.Slot);
        local vName = string.match(vLink or "", "%[(.-)%]");

        if vName then
            local vAdded = OutfitterQuickSwap_ToggleQueueItem(gQS_PopupSlot, vName);

            OutfitterQuickSwap_UpdateQueueMark(gQS_PopupSlot);
            OutfitterQuickSwap_Message(vAdded and ("已加入自动排队：" .. vName) or ("已移出自动排队：" .. vName));
        end

        return;
    end

    -- 饰品模式（TrinketMode）：TrinketMenu.MenuTrinket_OnClick 同款落点语义
    -- （TrinketMenu.lua:649 slot = LeftButton and 13 or 14）——
    -- 左键 = 换入上面饰品栏（Trinket0Slot），右键 = 换入下面饰品栏（Trinket1Slot）；
    -- 圣物弹出列表仍换入圣物栏本身
    local vTargetSlot = gQS_PopupSlot;

    if gOutfitterQuickSwap_Settings.TrinketMode
        and (gQS_PopupSlot == "Trinket0Slot" or gQS_PopupSlot == "Trinket1Slot") then
        vTargetSlot = (pMouseButton == "RightButton") and "Trinket1Slot" or "Trinket0Slot";
    end

    OutfitterQuickSwap_UseItem(pButton, vTargetSlot);

    -- 点完收起（TrinketMenu KeepOpen=OFF 默认行为；开启备选框常显时不收起，同款判断）
    if not gOutfitterQuickSwap_Settings.PopupAlways then
        OutfitterQuickSwapPopup:Hide();
        gQS_PopupOwner = nil;
        gQS_PopupSlot = nil;
        gQS_HideAt = nil;
        OutfitterQuickSwap_ClearTooltip();
    end
end

-- 换装：新物品上光标 → 放入装备位，原装备自动回原背包格（TrinketMenu/GearMenu 模式）
-- pSlotName：目标部位覆盖（饰品模式左/右键分别换入饰品1/饰品2 用；缺省 = 弹出列表所属部位）
function OutfitterQuickSwap_UseItem(pButton, pSlotName)
    local vSlotName = pSlotName or gQS_PopupSlot;
    if not vSlotName or not pButton.Bag then
        return;
    end

    if CursorHasItem() or SpellIsTargeting() then
        return;
    end

    local vLink = GetContainerItemLink(pButton.Bag, pButton.Slot);

    -- 战斗中护甲类无法更换 → 按物品名排队（TrinketMenu.CombatQueue 模式），脱战后自动更换
    if UnitAffectingCombat("player") and not OutfitterQuickSwap_cCombatOkSlots[vSlotName] then
        local vName = string.match(vLink or "", "%[(.-)%]");

        if vName then
            gQS_CombatQueue[vSlotName] = vName;
            OutfitterQuickSwap_UpdateQueueMark(vSlotName);
            OutfitterQuickSwap_Message("战斗中无法更换，已排队脱战后自动更换：" .. vName);
        end

        return;
    end

    OutfitterQuickSwap_DoEquip(vSlotName, pButton.Bag, pButton.Slot, vLink);
end

--------------------------------------------------------------------------
-- 双手武器 / 副手 互斥处理
-- 1.12 引擎不允许「双手武器 + 副手物品」共存：主手是双手武器时直接往副手槽
-- Equip 会被引擎拒绝（物品留在光标上，表现就是"点了没反应"）。Outfitter 主
-- 逻辑（Outfitter.lua:3423 OptimizeEquipmentChangeList）换双手武器时会先插
-- 入一条清空副手的 change；这里做同样的事——换装前先腾空冲突的那只手。
--------------------------------------------------------------------------

-- 物品是否为双手武器（优先 Outfitter 的 MetaSlotName，equipLoc 扫描兜底。
-- 本客户端 GetItemInfo 返回布局与标准 1.12 不同，故按 ^INVTYPE_ 全参数扫描）
function OutfitterQuickSwap_IsTwoHandLink(pLink)
    if not pLink then
        return false;
    end

    if Outfitter_GetItemInfoFromLink then
        local vOK, vItem = pcall(Outfitter_GetItemInfoFromLink, pLink);

        if vOK and vItem and vItem.MetaSlotName == "TwoHandSlot" then
            return true;
        end
    end

    local vGetOK, vR1, vR2, vR3, vR4, vR5, vR6, vR7, vR8 = pcall(GetItemInfo, pLink);

    if vGetOK and vR1 then
        local vArgs = { vR1, vR2, vR3, vR4, vR5, vR6, vR7, vR8 };

        for vIndex = 1, table.getn(vArgs) do
            if vArgs[vIndex] == "INVTYPE_2HWEAPON" then
                return true;
            end
        end
    end

    return false;
end

-- 找背包空位（复用 Outfitter 现成实现，它已跳过箭袋/灵魂袋等专业包）
function OutfitterQuickSwap_FindEmptyBagSlot()
    if Outfitter_GetEmptyBagSlot then
        local vOK, vEmpty = pcall(Outfitter_GetEmptyBagSlot);

        if vOK and vEmpty and vEmpty.BagIndex then
            return vEmpty.BagIndex, vEmpty.BagSlotIndex;
        end
    end

    -- 兜底：自行扫描（bag 0..4）
    for vBag = 0, 4 do
        local vNumSlots = GetContainerNumSlots(vBag);

        for vSlot = 1, vNumSlots do
            if not GetContainerItemInfo(vBag, vSlot) then
                return vBag, vSlot;
            end
        end
    end

    return nil;
end

-- 把指定装备槽的物品卸回背包（空槽视为成功）。返回 false = 无法腾空
-- （背包已满或槽位正被锁定），调用方应放弃本次换装，避免物品粘在光标上。
function OutfitterQuickSwap_UnequipToBag(pSlotName, pMessage)
    local vSlotID = GetInventorySlotInfo(pSlotName);

    if not GetInventoryItemTexture("player", vSlotID) then
        return true; -- 空槽：无需处理
    end

    if IsInventoryItemLocked(vSlotID) then
        return false;
    end

    local vBag, vSlot = OutfitterQuickSwap_FindEmptyBagSlot();
    local vLabel = pSlotName;

    if pSlotName == "MainHandSlot" then
        vLabel = "主手";
    elseif pSlotName == "SecondaryHandSlot" then
        vLabel = "副手";
    end

    if not vBag then
        OutfitterQuickSwap_Message("背包已满，无法卸下" .. vLabel .. "物品");
        return false;
    end

    local vName = string.match(GetInventoryItemLink("player", vSlotID) or "", "%[(.-)%]");

    PickupInventoryItem(vSlotID);
    PickupContainerItem(vBag, vSlot);

    if vName then
        OutfitterQuickSwap_Message(pMessage .. vName);
    end

    return true;
end

-- 副手"唯一槽"物品（盾牌 / 副手物品 / 副手武器）：这类物品只能进副手槽，
-- 直接走 UseContainerItem（＝背包右键装备），与原生行为完全一致——主手是双手
-- 武器时引擎会自动把双手武器卸回背包。
-- 不能对所有副手候选都这么干：单手武器（INVTYPE_WEAPON）右键会被装到主手槽，
-- 那种情况必须走指定槽的 Pickup 路径（见 ResolveHandConflict）。
function OutfitterQuickSwap_IsOffHandOnlyItem(pBag, pSlotNum)
    local vInfo = OutfitterQuickSwap_GetBagItem(pBag, pSlotNum);

    if not vInfo then
        return false;
    end

    if vInfo.ItemSlotName == "SecondaryHandSlot" then
        return true;
    end

    return vInfo.EquipLoc == "INVTYPE_SHIELD"
        or vInfo.EquipLoc == "INVTYPE_HOLDABLE"
        or vInfo.EquipLoc == "INVTYPE_WEAPONOFFHAND";
end

-- 换装前处理双手/副手互斥：返回 false 表示本次换装应中止
function OutfitterQuickSwap_ResolveHandConflict(pSlotName, pBag, pSlotNum)
    if pSlotName == "SecondaryHandSlot" then
        -- 装副手：主手是双手武器 → 先卸下双手武器
        local vMainHandID = GetInventorySlotInfo("MainHandSlot");

        if OutfitterQuickSwap_IsTwoHandLink(GetInventoryItemLink("player", vMainHandID)) then
            return OutfitterQuickSwap_UnequipToBag("MainHandSlot", "已卸下双手武器：");
        end

    elseif pSlotName == "MainHandSlot" then
        -- 装双手武器到主手：副手有物品 → 先卸下副手
        if OutfitterQuickSwap_IsTwoHandLink(GetContainerItemLink(pBag, pSlotNum)) then
            return OutfitterQuickSwap_UnequipToBag("SecondaryHandSlot", "已卸下副手：");
        end
    end

    return true;
end

-- 实际执行换装（PickupContainerItem + PickupInventoryItem 互换）
function OutfitterQuickSwap_DoEquip(pSlotName, pBag, pSlotNum, pLink)
    local vSlotID = GetInventorySlotInfo(pSlotName);

    if IsInventoryItemLocked(vSlotID) then
        return false;
    end

    local _, _, vBagLocked = GetContainerItemInfo(pBag, pSlotNum);

    if vBagLocked then
        return false;
    end

    -- 副手"唯一槽"物品走原生使用路径（＝背包右键装备）：引擎自己会卸下主手
    -- 双手武器。原来统一走 PickupContainerItem + PickupInventoryItem(17)（＝
    -- EquipCursorItem，"拖拽放置"路径），这条路径引擎不做自动腾手 → 直接拒绝，
    -- 物品留在光标上（用户所见"点了没反应"）。
    if pSlotName == "SecondaryHandSlot"
        and OutfitterQuickSwap_IsOffHandOnlyItem(pBag, pSlotNum) then
        if OutfitterQuickSwap_IsTwoHandLink(GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))) then
            OutfitterQuickSwap_Message("主手双手武器将被卸下以装备副手");
        end

        UseContainerItem(pBag, pSlotNum);

        gQS_ForceRefreshAt = GetTime() + 0.75;
        OutfitterQuickSwap_RequestRefresh();
        return true;
    end

    -- 双手武器与副手互斥：换装前先把冲突的那只手腾空（详见 ResolveHandConflict）。
    -- 腾不出来（背包满/槽位锁定）就直接放弃，不做 Pickup——否则物品会粘在光标上。
    if not OutfitterQuickSwap_ResolveHandConflict(pSlotName, pBag, pSlotNum) then
        gQS_ForceRefreshAt = GetTime() + 0.75;
        OutfitterQuickSwap_RequestRefresh();
        return false;
    end

    PickupContainerItem(pBag, pSlotNum);
    PickupInventoryItem(vSlotID);

    -- 换装可能失败（被眩晕等）：图标先置灰（TrinketMenu.SetDesaturated 同款视觉反馈），
    -- 0.75s 后无条件强制刷新一次兜底（TrinketMenu StartTimer("UpdateWornTrinkets") 模式）
    for vIndex = 1, table.getn(gQS_SlotButtons) do
        local vButton = gQS_SlotButtons[vIndex];

        if vButton.Slot == pSlotName then
            pcall(vButton.Icon.SetDesaturated, vButton.Icon, 1);
        end
    end

    gQS_ForceRefreshAt = GetTime() + 0.75;
    OutfitterQuickSwap_RequestRefresh();
    return true;
end

-- 脱战/复活/跑尸后按队列执行换装（TrinketMenu.OnEvent 战斗队列模式：按名字重新定位）
function OutfitterQuickSwap_ProcessQueuedSwap()
    if not gQS_CombatQueue
        or OutfitterQuickSwap_IsPlayerReallyDead() then
        return;
    end

    -- 先收集待处理部位（避免遍历时修改表）；暂停部位跳过且不清除其排队物品
    local vSlotNames = {};

    for vSlotName, _ in pairs(gQS_CombatQueue) do
        if not gOutfitterQuickSwap_Settings.PausedSlots[vSlotName] then
            table.insert(vSlotNames, vSlotName);
        end
    end

    for _, vSlotName in vSlotNames do
        local vName = gQS_CombatQueue[vSlotName];

        gQS_CombatQueue[vSlotName] = nil;
        OutfitterQuickSwap_UpdateQueueMark(vSlotName);

        if vName then
            local vBag, vSlot = OutfitterQuickSwap_FindItemByName(vName);

            if vBag then
                if OutfitterQuickSwap_DoEquip(vSlotName, vBag, vSlot, GetContainerItemLink(vBag, vSlot)) then
                    OutfitterQuickSwap_Message("已自动更换：" .. vName);
                end
            else
                OutfitterQuickSwap_Message("自动更换取消：背包中找不到 " .. vName);
            end
        end
    end
end

-- 自动排队处理（TrinketMenu.ProcessAutoQueue 模式）：
-- 已装备物品进长冷却（剩余>30s，即"刚用掉"）时，按队列顺序换上背包中
-- 第一个就绪（无冷却或剩余<=30s）的排队物品；战斗中转入战斗队列脱战再换。
-- 当前装备就绪时不动作（不自动换回，避免就绪/冷却来回抖动，TrinketMenu 同策略）
function OutfitterQuickSwap_ProcessAutoQueue(pSlotName)
    local vQueue = gOutfitterQuickSwap_Settings.Queues[pSlotName];

    if not vQueue or table.getn(vQueue) == 0
        or gOutfitterQuickSwap_Settings.PausedSlots[pSlotName]   -- 该部位排队已暂停
        or OutfitterQuickSwap_IsPlayerReallyDead() then
        return;
    end

    local vSlotID = GetInventorySlotInfo(pSlotName);

    if IsInventoryItemLocked(vSlotID) then
        return; -- 槽位正在交换
    end

    local vEquipped = string.match(GetInventoryItemLink("player", vSlotID) or "", "%[(.-)%]");

    if not vEquipped then
        return; -- 空槽不动
    end

    -- 就绪判定（TrinketMenu.TrinketNearReady 同款：无冷却或剩余 <=30s）
    local vStart, vDuration = GetInventoryItemCooldown("player", vSlotID);
    local vEquippedReady = vStart == 0 or (vDuration - (GetTime() - vStart)) <= 30;
    local vEquippedIsPrio = gOutfitterQuickSwap_Settings.QueuePriorities[vEquipped] and true or false;

    -- 当前装备 = 就绪的优先物品：它就是被优先换上来的那个，保持使用
    -- （防两个就绪优先物品互相拉扯换装）
    if not (vEquippedReady and vEquippedIsPrio) then
        -- 优先物品（TrinketMenu「优先」同款语义）：按队列顺序找第一个**就绪**的
        -- 优先物品，找到就立即换上使用——不受「当前装备可用即保持」与延迟保护
        -- 约束（优先 = 插队尽快用掉它）。优先物品没就绪时落回下方常规逻辑
        for vIndex = 1, table.getn(vQueue) do
            local vPName = vQueue[vIndex];

            if vPName ~= vEquipped and gOutfitterQuickSwap_Settings.QueuePriorities[vPName] then
                local vBag, vSlot = OutfitterQuickSwap_FindItemByName(vPName);

                if vBag then
                    local vPStart, vPDuration = GetContainerItemCooldown(vBag, vSlot);

                    if vPStart == 0 or (vPDuration - (GetTime() - vPStart)) <= 30 then
                        if UnitAffectingCombat("player") and not OutfitterQuickSwap_cCombatOkSlots[pSlotName] then
                            -- 战斗中：转入战斗队列（与常规候选同款脱战执行）
                            if gQS_CombatQueue[pSlotName] ~= vPName then
                                gQS_CombatQueue[pSlotName] = vPName;
                                OutfitterQuickSwap_UpdateQueueMark(pSlotName);
                            end
                        else
                            OutfitterQuickSwap_DoEquip(pSlotName, vBag, vSlot, GetContainerItemLink(vBag, vSlot));
                        end

                        return; -- 一次只换一个
                    end
                end
            end
        end
    end

    if vEquippedReady then
        return; -- 当前装备可用：保持
    end

    -- 延迟替换（TrinketMenu.ProcessAutoQueue 的 Stats[id].delay 同款语义，
    -- TrinketMenuQueue.lua:330-337）：已装备物品配置了延迟、且距触发（冷却开始）
    -- 不足 N 秒时不换下，保护 buff 跑满（如大地之击需要 20 秒拿满 buff）。
    -- 走到这里必然 vStart>0 且冷却剩余 >30s，与原版判断条件等价，只补经过时间。
    local vDelay = gOutfitterQuickSwap_Settings.QueueDelays
        and gOutfitterQuickSwap_Settings.QueueDelays[vEquipped];

    if vDelay and vDelay > 0 and (GetTime() - vStart) < vDelay then
        return; -- 刚触发不久，延迟期内不换下
    end

    -- 候选（TrinketMenu 原版语义，TrinketMenuQueue.lua:349-357）：原版只在
    -- "已装备就绪"时才用它在队列中的位置截断候选（而就绪时本就不换）；
    -- 装备在冷却中时扫描直达队尾隐式 stop 标记 → **全员候选**。此前移植
    -- 无条件用已装备位置截断，导致队首饰品冷却后候选为空、永不换装。
    -- （就绪的情形已在上面 return，走到这里必然是冷却中 → 全员候选）
    for vIndex = 1, table.getn(vQueue) do
        local vName = vQueue[vIndex];

        if vName ~= vEquipped then
            local vBag, vSlot = OutfitterQuickSwap_FindItemByName(vName);

            if vBag then
                local vBStart, vBDuration = GetContainerItemCooldown(vBag, vSlot);

                if vBStart == 0 or (vBDuration - (GetTime() - vBStart)) <= 30 then
                    if UnitAffectingCombat("player") and not OutfitterQuickSwap_cCombatOkSlots[pSlotName] then
                        -- 战斗中：转入战斗队列（复用现有角标与脱战执行）
                        if gQS_CombatQueue[pSlotName] ~= vName then
                            gQS_CombatQueue[pSlotName] = vName;
                            OutfitterQuickSwap_UpdateQueueMark(pSlotName);
                        end
                    else
                        OutfitterQuickSwap_DoEquip(pSlotName, vBag, vSlot, GetContainerItemLink(vBag, vSlot));
                    end

                    return; -- 一次只换一个，下个检查周期再看
                end
            end
        end
    end
end

function OutfitterQuickSwap_OpenPopup(pSlotName, pOwnerButton)
    gQS_PopupSlot = pSlotName;
    gQS_PopupOwner = pOwnerButton;
    gQS_HideAt = nil;

    -- 按住 Alt 时显示屏蔽装备（让用户能看到、Alt+右键恢复）；释放 Alt 后下次打开重新过滤
    local vShowHidden = IsAltKeyDown() and true or false;
    gQS_PopupShowHidden = vShowHidden;

    -- 弹出列表标题
    local vLabel = pSlotName;
    for _, vSlot in OutfitterQuickSwap_cSlots do
        if vSlot.Slot == pSlotName then
            vLabel = vSlot.Short or vSlot.Label;
            break;
        end
    end
    -- 紧凑网格样式：不显示标题行与关闭按钮（TrinketMenu 同款）
    OutfitterQuickSwapPopupTitle:SetText(vLabel);
    OutfitterQuickSwapPopupTitle:Hide();
    if OutfitterQuickSwapPopupClose then
        OutfitterQuickSwapPopupClose:Hide();
    end

    local vItems = OutfitterQuickSwap_CollectBagItems(pSlotName, vShowHidden);
    local vNumItems = table.getn(vItems);

    -- 列数自适应（TrinketMenu.BuildMenu 同款：>24→5列，>18→4列，>12→3列，>4→2列）
    local vCols = 1;

    if vNumItems > 24 then
        vCols = 5;
    elseif vNumItems > 18 then
        vCols = 4;
    elseif vNumItems > 12 then
        vCols = 3;
    elseif vNumItems > 4 then
        vCols = 2;
    end

    -- 间距（TrinketMenu 弹出网格观感）：pfUI 环境下物品间留 2px 等间隙、
    -- 四周 2px 等边距；经典边框环模式保持紧贴（UI-Quickslot2 环外扩 11px
    -- 互相咬合成整体，加间隙反而散）
    local vGap = pfUI and 2 or gQS_PopupGap;
    local vPad = pfUI and 2 or 8;

    for vIndex = 1, gQS_MaxItems do
        local vButton = OutfitterQuickSwap_GetGridButton(vIndex);

        if vIndex <= vNumItems then
            local vInfo = vItems[vIndex];

            vButton.Bag = vInfo.Bag;
            vButton.Slot = vInfo.Slot;
            vButton.Name = vInfo.Name;

            -- SetTexture(nil) 或 "" 等于清空 texture，按钮会显示 pfUI 棕色 backdrop（用户截图里
            -- 看到的那种"空格子"）。兜底成问号占位贴图，至少能区分"无数据"和"真无贴图"。
            local vTex = vInfo.Texture;
            if not vTex or vTex == "" then
                vTex = "Interface\\Icons\\INV_Misc_QuestionMark";
            end
            vButton.Icon:SetTexture(vTex);
            vButton.Icon:Show();

            -- 屏蔽物品染灰（按住 Alt 时全显的项里，被屏蔽的置灰，方便识别哪些已屏蔽）。
            -- 本客户端实测 SetDesaturated(1) 对 36x36 物品贴图会触发渲染异常（texture 直接消失），
            -- 改用 SetVertexColor(.5,.5,.5) 染暗灰——顶点色乘法叠加，绝对不破坏 texture 显示。
            -- 同时强制归位 vertexColor = (1,1,1) 以防其他代码路径（pfUI 皮肤等）残留旧色。
            local vIsHidden = gOutfitterQuickSwap_Settings.HiddenItems
                              and gOutfitterQuickSwap_Settings.HiddenItems[vInfo.Name];

            if vIsHidden then
                vButton.Icon:SetVertexColor(0.45, 0.45, 0.45);
            else
                vButton.Icon:SetVertexColor(1, 1, 1);
            end

            if vInfo.Count and vInfo.Count > 1 then
                vButton.Count:SetText(vInfo.Count);
            else
                vButton.Count:SetText("");
            end

            local vR, vG, vB = 0.6, 0.6, 0.6;

            if vInfo.Quality then
                local vOK, vQR, vQG, vQB = pcall(GetItemQualityColor, vInfo.Quality);
                if vOK then
                    vR, vG, vB = vQR, vQG, vQB;
                end
            end

            OutfitterQuickSwap_SetBorderColor(vButton, vR, vG, vB);

            OutfitterQuickSwap_SetCooldownDisplay(vButton, GetContainerItemCooldown(vInfo.Bag, vInfo.Slot));

            local vRow = math.floor((vIndex - 1) / vCols);
            local vCol = math.mod(vIndex - 1, vCols);

            vButton:ClearAllPoints();
            vButton:SetPoint(
                "TOPLEFT",
                "OutfitterQuickSwapPopup",
                "TOPLEFT",
                vPad + vCol * (gQS_CellSize + vGap),
                -(vPad + vRow * (gQS_CellSize + vGap))
            );

            vButton:Show();
        else
            vButton.Bag = nil;
            vButton.Slot = nil;
            vButton:Hide();

            OutfitterQuickSwap_SetCooldownDisplay(vButton, 0, 0);
        end
    end

    -- 尺寸与定位：紧贴锚定按钮（方向由设置决定：向上 / 向下）
    -- 四周等边距（vPad）+ 物品间等间隙（vGap）
    local vRows = math.max(1, math.ceil(vNumItems / vCols));
    local vWidth = vPad * 2 + vCols * gQS_CellSize + (vCols - 1) * vGap;

    OutfitterQuickSwapPopup:SetWidth(vWidth);
    OutfitterQuickSwapPopup:SetHeight(vPad * 2 + vRows * gQS_CellSize + (vRows - 1) * vGap);

    -- 弹出框缩放跟随锚定按钮所属分栏（两分栏可各自缩放；无锚定按钮时用分栏1）
    if pOwnerButton and pOwnerButton.GetParent then
        local vOwnerFrame = pOwnerButton:GetParent();

        if vOwnerFrame and vOwnerFrame.GetScale then
            OutfitterQuickSwapPopup:SetScale(vOwnerFrame:GetScale() or 1);
        end
    end

    OutfitterQuickSwapPopup:ClearAllPoints();

    if pOwnerButton then
        if gOutfitterQuickSwap_Settings.PopupUp then
            OutfitterQuickSwapPopup:SetPoint("BOTTOMLEFT", pOwnerButton, "TOPLEFT", 0, 2);
        else
            OutfitterQuickSwapPopup:SetPoint("TOPLEFT", pOwnerButton, "BOTTOMLEFT", 0, -2);
        end
    else
        OutfitterQuickSwapPopup:SetPoint("BOTTOMLEFT", "OutfitterQuickSwapFrame", "TOPLEFT", 0, 6);
    end

    OutfitterQuickSwapPopup:Show();

    -- 空状态提示：根据"是否有屏蔽装备"决定话术
    -- （即便当前没按 Alt，主动让用户知道列表里"少东西"是有原因的）
    if vNumItems == 0 then
        local vMsg = "背包中没有该部位的装备";

        if not vShowHidden then
            local vHiddenCount = 0;

            for _, vSlot in OutfitterQuickSwap_cSlots do
                if vSlot.Slot == pSlotName then
                    for vBag = 0, 4 do
                        local vNumSlots = GetContainerNumSlots(vBag);

                        for vS = 1, vNumSlots do
                            local vInfo = OutfitterQuickSwap_GetBagItem(vBag, vS);

                            if vInfo and OutfitterQuickSwap_ItemMatchesSlot(vInfo, pSlotName)
                                and gOutfitterQuickSwap_Settings.HiddenItems[vInfo.Name] then
                                vHiddenCount = vHiddenCount + 1;
                            end
                        end
                    end

                    break;
                end
            end

            if vHiddenCount > 0 then
                vMsg = "按住 Alt 显示 " .. vHiddenCount .. " 件已屏蔽装备";
            end
        end

        OutfitterQuickSwapPopupEmptyText:SetText(vMsg);
        OutfitterQuickSwapPopupEmptyText:Show();
    else
        OutfitterQuickSwapPopupEmptyText:Hide();
    end
end

--------------------------------------------------------------------------
-- 显隐 / 事件 / 刷新
--------------------------------------------------------------------------

function OutfitterQuickSwap_Toggle()
    if not OutfitterQuickSwapFrame then
        OutfitterQuickSwap_Message("面板未初始化成功，请把聊天框中「初始化出错」的信息发给开发者。");
        return;
    end

    if OutfitterQuickSwapFrame:IsShown() then
        OutfitterQuickSwapFrame:Hide();
    else
        OutfitterQuickSwapFrame:Show();
        OutfitterQuickSwap_RebuildBar();
    end
end

function OutfitterQuickSwap_OnShow()
    OutfitterQuickSwap_RebuildBar();
end

function OutfitterQuickSwap_OnHide()
    if OutfitterQuickSwapPopup then
        OutfitterQuickSwapPopup:Hide();
    end
    -- 分栏2 跟随主框关闭（再次显示时 RebuildBar 会按饰品模式重新拉起）
    if OutfitterQuickSwapFrame2 then
        OutfitterQuickSwapFrame2:Hide();
    end
    OutfitterQuickSwap_ClearTooltip();
    OutfitterQuickSwap_SaveSettings();
end

function OutfitterQuickSwap_RequestRefresh()
    if OutfitterQuickSwapFrame:IsShown() then
        gQS_PendingRefresh = true;
    end
end

function OutfitterQuickSwap_RefreshBar()
    gQS_LastRefresh = GetTime();
    gQS_PendingRefresh = nil;

    if not OutfitterQuickSwapFrame:IsShown() then
        return;
    end

    for vIndex = 1, table.getn(gQS_SlotButtons) do
        local vButton = gQS_SlotButtons[vIndex];
        if vButton.Slot and vButton:IsShown() then
            OutfitterQuickSwap_UpdateSlotButton(vButton);
        end
    end
end

function OutfitterQuickSwap_OnEvent()
    local vEvent = event;

    if vEvent == "PLAYER_ENTERING_WORLD" then
        -- 存档此时已加载
        OutfitterQuickSwap_LoadSettings();
        OutfitterQuickSwap_RebuildBar();
        OutfitterQuickSwap_FixTabLayout(); -- pfUI 加载晚于本插件，标签重排到进服才真正生效
        OutfitterQuickSwap_CheckFirstTrinket(); -- 已有饰品则自动弹出（TrinketMenu 登录判定）

    elseif vEvent == "BAG_UPDATE" then
        OutfitterQuickSwap_RequestRefresh();
        OutfitterQuickSwap_CheckRelicVisibility(); -- 圣物获得/用尽 → 饰品模式远程栏显隐

    elseif vEvent == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            OutfitterQuickSwap_CheckFirstTrinket(); -- 游戏中首次穿戴上饰品 → 自动弹出
            OutfitterQuickSwap_RequestRefresh();
            OutfitterQuickSwap_CheckRelicVisibility();
        end

    elseif vEvent == "PLAYER_REGEN_ENABLED" or vEvent == "PLAYER_ALIVE" or vEvent == "PLAYER_UNGHOST" then
        -- 脱战/复活/跑尸：执行战斗中排队的换装（TrinketMenu.OnEvent 同款三事件）
        if not OutfitterQuickSwap_IsPlayerReallyDead() then
            OutfitterQuickSwap_ProcessQueuedSwap();
        end

    elseif vEvent == "UPDATE_BINDINGS" then
        -- 按键设置改动后刷新按钮上的按键文字（TrinketMenu.OnEvent UPDATE_BINDINGS 同款）
        OutfitterQuickSwap_ReflectKeyBindings();

    elseif vEvent == "MODIFIER_STATE_CHANGED" then
        -- Alt 状态变化：弹出列表打开时实时刷新（按 Alt = 显示屏蔽装备并染灰；松 Alt = 重新过滤）
        if arg1 == "LALT" or arg1 == "RALT" or arg1 == "LSHIFT" or arg1 == "RSHIFT" then
            if gQS_PopupSlot and OutfitterQuickSwapPopup and OutfitterQuickSwapPopup:IsShown() then
                local vAltDown = IsAltKeyDown();
                local vWantShow = vAltDown and true or false;

                if gQS_PopupShowHidden ~= vWantShow then
                    OutfitterQuickSwap_OpenPopup(gQS_PopupSlot, gQS_PopupOwner);
                end
            end
        end

    elseif vEvent == "PLAYER_LOGOUT" then
        OutfitterQuickSwap_SaveSettings();
    end
end

function OutfitterQuickSwap_OnUpdate(pElapsed)
    -- 缩放百分比提示显示 1s 后消失
    if gQS_ScaleTextHideAt and GetTime() > gQS_ScaleTextHideAt then
        gQS_ScaleTextHideAt = nil;
        if OutfitterQuickSwapScaleText then
            OutfitterQuickSwapScaleText:Hide();
        end
    end

    -- 背包事件可能高频触发，合并刷新（节流 0.15s）
    if gQS_PendingRefresh and GetTime() - gQS_LastRefresh > 0.15 then
        OutfitterQuickSwap_RefreshBar();
    end

    -- 冷却每 0.5s 刷新一次（装备/饰品冷却走秒不依赖背包事件）
    if OutfitterQuickSwapFrame:IsShown() and GetTime() - gQS_LastCooldownCheck > 0.5 then
        gQS_LastCooldownCheck = GetTime();

        for vIndex = 1, table.getn(gQS_SlotButtons) do
            local vButton = gQS_SlotButtons[vIndex];

            if vButton.Slot and vButton:IsShown() then
                local vSlotID = GetInventorySlotInfo(vButton.Slot);
                OutfitterQuickSwap_SetCooldownDisplay(vButton, GetInventoryItemCooldown("player", vSlotID));
            end
        end

        -- 弹出网格里的倒计时文字同步走秒
        if OutfitterQuickSwapPopup and OutfitterQuickSwapPopup:IsShown() then
            for vIndex = 1, table.getn(gQS_GridButtons) do
                local vGridButton = gQS_GridButtons[vIndex];

                if vGridButton.Bag and vGridButton:IsShown() then
                    OutfitterQuickSwap_SetCooldownDisplay(vGridButton, GetContainerItemCooldown(vGridButton.Bag, vGridButton.Slot));
                end
            end
        end
    end

    -- 换装后兜底刷新（TrinketMenu StartTimer 模式：可能换装失败/无事件，0.75s 后强制同步一次）
    if gQS_ForceRefreshAt and GetTime() >= gQS_ForceRefreshAt then
        gQS_ForceRefreshAt = nil;
        OutfitterQuickSwap_RefreshBar();
    end

    -- 悬停弹出的自动收起：鼠标同时离开锚定按钮和弹出框，宽限 0.75s（TrinketMenu 手感）。
    -- 备选框常显（PopupAlways，TrinketMenu KeepOpen 同款）时不安排收起，已排队的也取消
    if gQS_HideAt then
        if gOutfitterQuickSwap_Settings.PopupAlways then
            gQS_HideAt = nil;
        elseif GetTime() >= gQS_HideAt then
            if OutfitterQuickSwapPopup then
                OutfitterQuickSwapPopup:Hide();
            end
            gQS_PopupOwner = nil;
            gQS_PopupSlot = nil;
            gQS_HideAt = nil;
        end
    elseif gQS_PopupOwner and OutfitterQuickSwapPopup and OutfitterQuickSwapPopup:IsShown() then
        if not gOutfitterQuickSwap_Settings.PopupAlways
            and not MouseIsOver(gQS_PopupOwner) and not MouseIsOver(OutfitterQuickSwapPopup) then
            gQS_HideAt = GetTime() + 0.75;
        end
    end
end

--------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------

local function OutfitterQuickSwap_Initialize()
    -- 给 cSlots 标上序号（设置区定位用）
    for vIndex, vSlot in OutfitterQuickSwap_cSlots do
        vSlot.Index = vIndex;
    end

    local vFrame = CreateFrame("Frame", "OutfitterQuickSwapFrame", UIParent);
    vFrame:SetFrameStrata("HIGH");
    vFrame:SetMovable(true);
    vFrame:SetToplevel(true);
    vFrame:SetWidth(256);
    vFrame:SetHeight(120);
    -- 默认位置 = 用户指定 BOTTOMLEFT 偏移原值（与存档 X/Y 同锚定方式）；
    -- 有存档时 LoadSettings 会按存档重锚，此处仅覆盖进服前的一瞬
    vFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 1122.531336708608, 275.5310979687554);
    vFrame:Hide();

    vFrame:SetBackdrop({
        -- TrinketMenu.xml:110 同款：石纹底 + tooltip 边框（pfUI 环境下由
        -- pfui-skin 置透明接管，此贴图仅在无 pfUI 的经典路径可见）
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    });
    vFrame:SetBackdropColor(0, 0, 0, 0.9);

    vFrame:SetScript("OnShow", function() OutfitterQuickSwap_OnShow(); end);
    vFrame:SetScript("OnHide", function() OutfitterQuickSwap_OnHide(); end);
    vFrame:SetScript("OnUpdate", function() OutfitterQuickSwap_OnUpdate(arg1); end);

    -- 滚轮缩放（0.5x-2.0x；子控件未开 EnableMouseWheel，滚轮事件冒泡到本帧）
    vFrame:EnableMouseWheel(true);
    vFrame:SetScript("OnMouseWheel", function() OutfitterQuickSwap_OnMouseWheel(arg1); end);

    -- 拖动区鼠标提示：悬停在标题栏/栏位条空白处（可拖动区域）时提示操作方式。
    -- 物品按钮自身带 OnEnter 会拦截悬停，本提示只在按钮之间的空隙生效
    local function BarTipOnEnter()
        GameTooltip:SetOwner(this, "ANCHOR_TOP");
        GameTooltip:ClearLines();
        if gOutfitterQuickSwap_Settings.Locked then
            GameTooltip:AddLine("快速换装（已锁定）", 1, 0.82, 0);
            GameTooltip:AddLine("右键打开菜单可解锁拖动/缩放", 0.8, 0.8, 0.8);
        else
            GameTooltip:AddLine("快速换装", 1, 1, 1);
            GameTooltip:AddLine("按住鼠标左键拖动移动", 0.9, 0.9, 0.9);
            GameTooltip:AddLine("滚轮缩放　右键打开菜单", 0.8, 0.8, 0.8);
        end
        GameTooltip:Show();
    end
    local function BarTipOnLeave()
        GameTooltip:Hide();
    end

    -- 标题栏（可拖动）
    local vTitleBar = CreateFrame("Frame", "OutfitterQuickSwapTitleBar", vFrame);
    vTitleBar:SetHeight(22);
    vTitleBar:SetPoint("TOPLEFT", vFrame, "TOPLEFT", 6, -6);
    vTitleBar:SetPoint("TOPRIGHT", vFrame, "TOPRIGHT", -28, -6);
    vTitleBar:EnableMouse(true);
    vTitleBar:EnableMouseWheel(true);
    vTitleBar:SetScript("OnMouseWheel", function() OutfitterQuickSwap_OnMouseWheel(arg1); end);

    vTitleBar:SetScript("OnMouseDown", function()
        if arg1 == "RightButton" then
            OutfitterQuickSwap_ToggleMenu();
            return;
        end

        if not gOutfitterQuickSwap_Settings.Locked then
            vFrame:StartMoving();
        end
    end);
    vTitleBar:SetScript("OnMouseUp", function()
        vFrame:StopMovingOrSizing();
        OutfitterQuickSwap_ReanchorFrame();
        OutfitterQuickSwap_SaveSettings();
    end);
    vTitleBar:SetScript("OnEnter", BarTipOnEnter);
    vTitleBar:SetScript("OnLeave", BarTipOnLeave);

    local vTitle = vTitleBar:CreateFontString("OutfitterQuickSwapTitle", "OVERLAY", "GameFontNormal");
    vTitle:SetPoint("LEFT", vTitleBar, "LEFT", 2, 0);
    vTitle:SetText("快速换装");

    -- 关闭按钮
    local vClose = CreateFrame("Button", "OutfitterQuickSwapClose", vFrame, "UIPanelCloseButton");
    vClose:SetPoint("TOPRIGHT", vFrame, "TOPRIGHT", -2, -2);

    -- 栏位条容器（本身可拖动：精简模式下没有标题栏，靠间隙拖动）
    local vBar = CreateFrame("Frame", "OutfitterQuickSwapBar", vFrame);
    -- 锚点一次设定、永不重锚：装备行钉在框体底边（底距 8），
    -- 切换精简/普通只改框体高度，装备行屏幕位置零位移（与模式解耦）
    vBar:SetPoint("BOTTOMLEFT", vFrame, "BOTTOMLEFT", 8, 8);
    vBar:SetPoint("BOTTOMRIGHT", vFrame, "BOTTOMRIGHT", -8, 8);
    vBar:EnableMouse(true);
    vBar:EnableMouseWheel(true);
    vBar:SetScript("OnMouseWheel", function() OutfitterQuickSwap_OnMouseWheel(arg1); end);

    vBar:SetScript("OnMouseDown", function()
        if arg1 == "RightButton" then
            OutfitterQuickSwap_ToggleMenu();
            return;
        end

        if not gOutfitterQuickSwap_Settings.Locked then
            vFrame:StartMoving();
        end
    end);
    vBar:SetScript("OnMouseUp", function()
        vFrame:StopMovingOrSizing();
        OutfitterQuickSwap_ReanchorFrame();
        OutfitterQuickSwap_SaveSettings();
    end);
    vBar:SetScript("OnEnter", BarTipOnEnter);
    vBar:SetScript("OnLeave", BarTipOnLeave);

    -- 空状态提示（锚定栏位条居中，精简/普通模式通用）
    local vEmpty = vFrame:CreateFontString("OutfitterQuickSwapEmptyText", "OVERLAY", "GameFontNormalSmall");
    vEmpty:SetPoint("CENTER", "OutfitterQuickSwapBar", "CENTER", 0, 0);
    vEmpty:SetText("在 Outfitter「快捷换装」页勾选要显示的部位");
    vEmpty:SetTextColor(0.7, 0.7, 0.7);
    vEmpty:Hide();

    -- 缩放百分比提示（滚轮缩放时短暂显示）
    local vScaleText = vFrame:CreateFontString("OutfitterQuickSwapScaleText", "OVERLAY", "GameFontNormalSmall");
    vScaleText:SetPoint("BOTTOMLEFT", vFrame, "TOPLEFT", 0, 2);
    vScaleText:SetTextColor(0.8, 0.8, 0.8);
    vScaleText:Hide();

    -- 分栏2（饰品模式第二栏「其余部位」）：独立框体——单独拖动/滚轮缩放/位置缩放
    -- 独立存档（Scale2/X2/Y2）。无标题栏（拖栏位条移动），右键弹同一菜单。
    -- pfUI 底板由 pfui-skin.lua 创建（CreateBackdrop + 经典底置透明），
    -- 显隐由 ApplyPanelStyle 统一管；无 pfUI 时走经典 SetBackdrop 路径。
    local vFrame2 = CreateFrame("Frame", "OutfitterQuickSwapFrame2", UIParent);
    vFrame2:SetFrameStrata("HIGH");
    vFrame2:SetMovable(true);
    vFrame2:SetToplevel(true);
    vFrame2:SetWidth(128);
    vFrame2:SetHeight(52);
    vFrame2:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 1122.53, 180);
    vFrame2:Hide();

    vFrame2:SetBackdrop({
        -- 与分栏1 同款：石纹底 + tooltip 边框（TrinketMenu.xml:110 观感）
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    });
    vFrame2:SetBackdropColor(0, 0, 0, 0.9);

    vFrame2:EnableMouseWheel(true);
    vFrame2:SetScript("OnMouseWheel", function() OutfitterQuickSwap_OnMouseWheel2(arg1); end);
    vFrame2:SetScript("OnHide", function()
        -- 弹出列表可能锚在分栏2 的按钮上，随框一起收
        if OutfitterQuickSwapPopup then
            OutfitterQuickSwapPopup:Hide();
        end
    end);

    -- 分栏2 栏位条（锚定框体底边一次、永不重锚——与分栏1 同一条布局铁律）
    local vBar2 = CreateFrame("Frame", "OutfitterQuickSwapBar2", vFrame2);
    vBar2:SetPoint("BOTTOMLEFT", vFrame2, "BOTTOMLEFT", 8, 8);
    vBar2:SetPoint("BOTTOMRIGHT", vFrame2, "BOTTOMRIGHT", -8, 8);
    vBar2:EnableMouse(true);
    vBar2:EnableMouseWheel(true);
    vBar2:SetScript("OnMouseWheel", function() OutfitterQuickSwap_OnMouseWheel2(arg1); end);

    vBar2:SetScript("OnMouseDown", function()
        if arg1 == "RightButton" then
            OutfitterQuickSwap_ToggleMenu();
            return;
        end

        if not gOutfitterQuickSwap_Settings.Locked then
            vFrame2:StartMoving();
        end
    end);
    vBar2:SetScript("OnMouseUp", function()
        vFrame2:StopMovingOrSizing();
        OutfitterQuickSwap_ReanchorFrame2();
        OutfitterQuickSwap_SaveSettings();
    end);
    vBar2:SetScript("OnEnter", BarTipOnEnter);
    vBar2:SetScript("OnLeave", BarTipOnLeave);


    -- 右键弹出列表（独立 tooplevel 框）。无整体背景（TrinketMenu 弹出样式：
    -- 物品各自带边框浮空排列，不垫底框）。
    local vPopup = CreateFrame("Frame", "OutfitterQuickSwapPopup", UIParent);
    -- strata 用 HIGH（与栏位条同层）：不能用 TOOLTIP 层——与 GameTooltip 同层时
    -- 悬停提示会被弹出框按钮盖住（TrinketMenu 框体是 LOW/MEDIUM，提示永远在上）
    vPopup:SetFrameStrata("HIGH");
    vPopup:SetToplevel(true);
    vPopup:SetWidth(256);
    vPopup:SetHeight(70);
    vPopup:Hide();

    -- 滚轮缩放（与栏位条/标题栏同款）：弹出框父级是 UIParent，滚轮事件不会冒泡到
    -- 换装栏 vFrame，必须自己接。物品按钮 OutfitterQuickSwapItem* 是它的子帧且
    -- 未开 EnableMouseWheel → 悬停物品上滚动时事件沿父链冒泡到本帧。
    -- 1.12 冒泡走父链而非逐层命中测试（参照 vFrame 的接法），故只需 EnableMouseWheel、
    -- 不必 EnableMouse(true)，也就不会吞掉弹出框空白处/物品的点击。
    vPopup:EnableMouseWheel(true);
    vPopup:SetScript("OnMouseWheel", function() OutfitterQuickSwap_OnMouseWheel(arg1); end);

    local vPopupTitle = vPopup:CreateFontString("OutfitterQuickSwapPopupTitle", "OVERLAY", "GameFontNormalSmall");
    vPopupTitle:SetPoint("TOPLEFT", vPopup, "TOPLEFT", 8, -6);
    vPopupTitle:SetText("同类装备");

    local vPopupClose = CreateFrame("Button", "OutfitterQuickSwapPopupClose", vPopup, "UIPanelCloseButton");
    vPopupClose:SetPoint("TOPRIGHT", vPopup, "TOPRIGHT", -2, -2);

    local vPopupEmpty = vPopup:CreateFontString("OutfitterQuickSwapPopupEmptyText", "OVERLAY", "GameFontNormalSmall");
    vPopupEmpty:SetPoint("CENTER", vPopup, "CENTER", 0, 0);
    vPopupEmpty:SetText("背包中没有该部位的装备");
    vPopupEmpty:SetTextColor(0.7, 0.7, 0.7);
    vPopupEmpty:Hide();

    -- 隐藏扫描 tooltip
    gQS_ScanTooltip = CreateFrame("GameTooltip", "OutfitterQuickSwapScanTooltip", nil, "GameTooltipTemplate");

    -- 面板右键菜单（锁定/停止排队；displayMode="MENU" + cursor 锚定，
    -- 1.12 经典光标菜单模式：直接设 initialize/displayMode 字段）
    local vMenuFrame = CreateFrame("Frame", "OutfitterQuickSwapDropDown", UIParent, "UIDropDownMenuTemplate");
    vMenuFrame.displayMode = "MENU";
    vMenuFrame.initialize = OutfitterQuickSwap_MenuInit;
    vMenuFrame:Hide();

    -- 事件帧（挂 UIParent：tooltip 每秒走秒刷新也由它的 OnUpdate 驱动，主面板隐藏时不中断）
    local vEventFrame = CreateFrame("Frame", "OutfitterQuickSwapEventFrame", UIParent);
    vEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
    vEventFrame:RegisterEvent("PLAYER_LOGOUT");
    vEventFrame:RegisterEvent("BAG_UPDATE");
    vEventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED");
    vEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
    vEventFrame:RegisterEvent("PLAYER_ALIVE");
    vEventFrame:RegisterEvent("PLAYER_UNGHOST");
    vEventFrame:RegisterEvent("UPDATE_BINDINGS");
    vEventFrame:RegisterEvent("MODIFIER_STATE_CHANGED");
    vEventFrame:SetScript("OnEvent", function() OutfitterQuickSwap_OnEvent(); end);
    vEventFrame:SetScript("OnUpdate", function()
        -- 悬停 tooltip 的每秒刷新（TrinketMenu.StartTimer("TooltipUpdate",1,1) 同款节奏）
        if gQS_TooltipType and GetTime() >= gQS_TooltipNext then
            gQS_TooltipNext = GetTime() + 1;
            OutfitterQuickSwap_TooltipUpdate();
        end

        -- 自动排队检查（TrinketMenu.PeriodicQueueCheck 模式：1s 节流，栏隐藏时也运行）
        if GetTime() - gQS_LastQueueCheck > 1 then
            gQS_LastQueueCheck = GetTime();

            for _, vSlot in OutfitterQuickSwap_cSlots do
                OutfitterQuickSwap_ProcessAutoQueue(vSlot.Slot);
            end
        end
    end);

    -- 创建「快捷换装」标签页（pcall 防止 XML 结构差异导致初始化失败）
    local vOptOK, vOptErr = pcall(OutfitterQuickSwap_BuildOptions);

    if not vOptOK then
        OutfitterQuickSwap_Message("创建快捷换装标签页失败: " .. tostring(vOptErr));
    end
end

-- 初始化（pcall 保护：出错时在聊天框报告，不阻断命令注册）
local vInitOK, vInitErr = pcall(OutfitterQuickSwap_Initialize);

if not vInitOK then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[快速换装] 初始化出错: |r" .. tostring(vInitErr));
    end
end;
