-- Outfitter pfUI 皮肤支持（独立模块）
-- 参考 XyTracker/pfui-skin.lua 的实现模式：
--   pfUI 存在时应用 pfUI 风格，全部改动仅作用于外观，不触碰任何现有逻辑
-- 内容从 Outfitter.lua 原 Outfitter_pfUISkin() 整体迁移，锚点/位置参数保持不变

-- 等待 pfUI 就绪的取环境函数
local function GetPFUIEnv()
    if pfUI and pfUI.api and pfUI.env and pfUI.env.C then
        return pfUI.api
    end
    return nil
end

-- 辅助：勾选框美化（SkinCheckbox + 勾选贴图内缩，原 skin_checkbox 样板）
local function skin_checkbox(api, cb)
    if not cb then return end
    api.SkinCheckbox(cb)
    local tex = cb:GetCheckedTexture()
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", 4, -4)
    tex:SetPoint("BOTTOMRIGHT", -4, 4)
end

-- 辅助：快捷换装页 18px 小勾选框美化（不改变尺寸）
-- 与 skin_checkbox 的差异：backdrop 完全贴合按钮本体（0 外扩，外扩会显得黑框比 ✓
-- 大一圈），勾选贴图内缩 2px；并恢复 CreateBackdrop 重置掉的命中区（方框+文字整块可点）。
local function skin_qs_checkbox(api, cb, hitRight)
    if not cb then return end
    api.SkinCheckbox(cb)

    if cb.backdrop then
        cb.backdrop:ClearAllPoints()
        cb.backdrop:SetPoint("TOPLEFT", 0, 0)
        cb.backdrop:SetPoint("BOTTOMRIGHT", 0, 0)
    end

    local tex = cb:GetCheckedTexture()
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", -2, 2)

    -- QuickSwap.lua 建框时设过 SetHitRectInsets(-6, -hitRight, -6, -6)，
    -- CreateBackdrop 会重设为边框宽，这里恢复原值
    cb:SetHitRectInsets(-6, hitRight, -6, -6)
end

-- 物品链接 |cffRRGGBB 品质色解析（Lua 5.0 无 tonumber("0x..")，逐字符 hex 转 0-1）
local function ParseQualityColor(pLink)
    if not pLink or type(pLink) ~= "string" then return nil end
    local r, g, b = string.match(pLink, "|cff(%x%x)(%x%x)(%x%x)")
    if not r then return nil end
    local function hexToFloat(h)
        local v = 0
        for i = 1, string.len(h) do
            local c = string.byte(string.sub(h, i, i))
            if c >= 48 and c <= 57 then v = v * 16 + (c - 48)        -- 0-9
            elseif c >= 97 and c <= 102 then v = v * 16 + (c - 87)    -- a-f
            elseif c >= 65 and c <= 70 then v = v * 16 + (c - 55)     -- A-F
            end
        end
        return v / 255
    end
    return hexToFloat(r), hexToFloat(g), hexToFloat(b)
end

-- 角色界面 QuickSlots 弹框（点击纸娃娃装备槽弹出）pfUI 美化
-- 1.12 Layer 0 BACKGROUND 纹理漏清陷阱：32 个 Back* 残留需按命名 getglobal 显式清，
-- pfUI.api.StripTextures 在这种场景不可靠
local function OutfitterQuickSlots_RefreshSkinPFUI()
    local api = GetPFUIEnv()
    if not api then return end
    local qsFrame = getglobal("OutfitterQuickSlots")
    if not qsFrame then return end

    -- 1. 框体：清 32 个 Back* 残留（Back0/BackStart1-2/Back1-26/BackEnd/BackEnd1-2）
    local backNames = { "Back0", "BackStart1", "BackStart2", "BackEnd", "BackEnd1", "BackEnd2" }
    for i = 1, 26 do table.insert(backNames, "Back" .. i) end
    for _, name in backNames do
        local tex = getglobal("OutfitterQuickSlots" .. name)
        if tex then
            tex:SetTexture(nil)
            tex:Hide()
        end
    end

    -- 2. 框体加 pfUI 深色板（幂等）
    if not qsFrame.backdrop then
        api.CreateBackdrop(qsFrame)
    end

    -- 3. 27 个槽位按钮（ContainerFrameItemButtonTemplate，与 QuickSwap Slot/Item 同款）
    for i = 1, 27 do
        local btn = getglobal("OutfitterQuickSlotsItem" .. i .. "Item1")
        if btn then
            -- 隐藏经典粗框（Blizzard NormalTexture / PushedTexture）
            if btn.GetNormalTexture then
                local t = btn:GetNormalTexture()
                if t then t:SetTexture(nil) end
            end
            if btn.GetPushedTexture then
                local t = btn:GetPushedTexture()
                if t then t:SetTexture(nil) end
            end
            -- 隐藏 quality Border（ContainerFrame_Update 每次 SetSlotToBag 会反复 Show/Hide）
            local border = getglobal(btn:GetName() .. "Border")
            if border then border:Hide() end

            -- 图标满铺 + TexCoord 微缩（与 QuickSwap Slot/Item 同款 .08 缩边距）
            local icon = getglobal(btn:GetName() .. "Icon")
            if icon then
                icon:SetAllPoints(btn)
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            -- 高亮贴图同款
            local hi = btn.GetHighlightTexture and btn:GetHighlightTexture()
            if hi then
                hi:SetAllPoints(btn)
                hi:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

            -- pfUI 深色细边框 backdrop（幂等；CreateBackdrop 内部会重设边框色为默认，
            -- 品质色需在创建后单独染）
            if not btn.backdrop then
                pcall(api.CreateBackdrop, btn)
            end

            -- 按物品品质染边框色（链接 |cffRRGGBB 解析；空槽或无 link 跳过，保留 pfUI 默认色）
            if btn.backdrop then
                local parent = btn:GetParent()
                if parent then
                    local bag = parent:GetID()
                    local slot = btn:GetID()
                    if bag and slot and bag > 0 and slot > 0 then
                        local link = GetContainerItemLink(bag, slot)
                        local r, g, b = ParseQualityColor(link)
                        if r then
                            btn.backdrop:SetBackdropBorderColor(r, g, b, 1)
                        end
                    end
                end
            end
        end
    end
end

-- 快捷换装「自动排队设置」窗口 pfUI 美化
-- 窗口由 QuickSwap.lua 懒创建（首次打开时才建），建窗末尾会调用本函数；
-- 本模块晚于 QuickSwap.lua 加载，运行时全局必然就绪。幂等，可重复调用。
function OutfitterQuickSwap_QueueCfgSkin(pFrame)
    local api = GetPFUIEnv()
    if not api then return end

    local vFrame = pFrame or getglobal("OutfitterQuickSwapQueueCfg")
    if not vFrame then return end

    -- 1. 主框：pfUI 深色板；经典 tooltip 底永久置透明（对 OutfitterQuickSwapFrame 同款）
    if not vFrame.backdrop then
        pcall(api.CreateBackdrop, vFrame)
    end
    if vFrame.backdrop then
        vFrame:SetBackdropColor(0, 0, 0, 0)
        vFrame:SetBackdropBorderColor(0, 0, 0, 0)
    end

    -- 2. 关闭按钮
    local vClose = getglobal("OutfitterQuickSwapQueueCfgClose")
    if vClose and not vClose.pfSkinned then
        pcall(api.SkinCloseButton, vClose, vFrame, -4, -4)
        vClose.pfSkinned = true
    end

    -- 3. 部位下拉
    local vDrop = getglobal("OutfitterQuickSwapQueueCfgSlotDrop")
    if vDrop and not vDrop.pfSkinned then
        pcall(api.SkinDropDown, vDrop)
        vDrop.pfSkinned = true
    end

    -- 4. 排序按钮（顶/上/下/底）：建窗时画的经典 tooltip 底置透明 + pfUI 细边
    for i = 1, 4 do
        local vBtn = getglobal("OutfitterQuickSwapQueueCfgMove" .. i)
        if vBtn and not vBtn.backdrop then
            vBtn:SetBackdropColor(0, 0, 0, 0)
            vBtn:SetBackdropBorderColor(0, 0, 0, 0)
            pcall(api.CreateBackdrop, vBtn)
        end
    end

    -- 5. 列表行：行体深色细边框（行池 1..N，getglobal 找到才处理，上限跟行池一致）
    for i = 1, 40 do
        local vRow = getglobal("OutfitterQuickSwapQueueCfgRow" .. i)
        if vRow and not vRow.backdrop then
            pcall(api.CreateBackdrop, vRow)
        end
    end

    -- 6. 延迟输入框：清 InputBoxTemplate 贴图 + backdrop（命名套装框 Name 输入框同款）
    local vEdit = getglobal("OutfitterQuickSwapQueueCfgDelayEdit")
    if vEdit and not vEdit.backdrop then
        pcall(api.StripTextures, vEdit, true, "BACKGROUND")
        pcall(api.CreateBackdrop, vEdit)
    end

    -- 7. 暂停勾选框（skin_qs_checkbox 同款：backdrop 0 外扩贴合 + 勾选贴图内缩 2px
    -- + 恢复 CreateBackdrop 重置掉的命中区，QuickSwap.lua 建框时设过 -4/-80）
    local vCheck = getglobal("OutfitterQuickSwapQueueCfgPauseCheck")
    if vCheck then
        pcall(api.SkinCheckbox, vCheck)

        if vCheck.backdrop then
            vCheck.backdrop:ClearAllPoints()
            vCheck.backdrop:SetPoint("TOPLEFT", 0, 0)
            vCheck.backdrop:SetPoint("BOTTOMRIGHT", 0, 0)
        end

        local tex = vCheck:GetCheckedTexture()
        if tex then
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", 2, -2)
            tex:SetPoint("BOTTOMRIGHT", -2, 2)
        end

        vCheck:SetHitRectInsets(-4, -80, -4, -4)
    end

    -- 8. 优先勾选框（同暂停勾选框模式：backdrop 贴合 + 勾选贴图内缩 + 恢复命中区；
    -- 文字「优先」在框右侧，命中区右扩 40 覆盖文字）
    local vPrio = getglobal("OutfitterQuickSwapQueueCfgPrioCheck")
    if vPrio then
        pcall(api.SkinCheckbox, vPrio)

        if vPrio.backdrop then
            vPrio.backdrop:ClearAllPoints()
            vPrio.backdrop:SetPoint("TOPLEFT", 0, 0)
            vPrio.backdrop:SetPoint("BOTTOMRIGHT", 0, 0)
        end

        local tex = vPrio:GetCheckedTexture()
        if tex then
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", 2, -2)
            tex:SetPoint("BOTTOMRIGHT", -2, 2)
        end

        vPrio:SetHitRectInsets(-4, -40, -4, -4)
    end
end

-- 主皮肤应用函数
local function ApplySkin()
    local api = GetPFUIEnv()
    if not api then return false end

    -- minimap 按钮图标与位置（pfUI 风格贴图）
    OutfitterButton:SetPoint("TOPRIGHT", -28, -40)
    OutfitterButton:SetNormalTexture("Interface\\Addons\\Outfitter\\Textures\\Outfitter-Button-pfUI")
    OutfitterButton:SetPushedTexture("Interface\\Addons\\Outfitter\\Textures\\Outfitter-Button-pfUI")

    -- 主窗口
    api.StripTextures(OutfitterFrame)
    api.CreateBackdrop(OutfitterFrame, nil, nil, .75)
    api.CreateBackdropShadow(OutfitterFrame)
    OutfitterFrame:SetPoint("TOPLEFT", OutfitterButtonFrame, "TOPRIGHT", -28, -40)
    OutfitterFrameTitle:SetPoint("TOP", 0, -6)
    OutfitterMainFrameButtonBarBackground:SetTexture(nil)

    api.SkinCloseButton(OutfitterCloseButton)
    OutfitterCloseButton:SetPoint("TOPRIGHT", -4, -4)

    api.SkinButton(OutfitterNewButton)
    OutfitterNewButton:SetPoint("BOTTOMRIGHT", -9, 4)

    api.SkinButton(OutfitterEnableAll)
    OutfitterEnableAll:SetPoint("TOP", -73, -80)

    api.SkinButton(OutfitterEnableNone)
    OutfitterEnableNone:SetPoint("TOP", 18, -80)

    api.StripTextures(OutfitterMainFrameScrollbarTrench)
    api.SkinScrollbar(OutfitterMainFrameScrollFrameScrollBar)

    api.SkinTab(OutfitterFrameTab1)
    api.SkinTab(OutfitterFrameTab2)
    api.SkinTab(OutfitterFrameTab3)
    if OutfitterFrameTab4 then
        api.SkinTab(OutfitterFrameTab4)
    end
    -- 标签布局恢复原版：SkinTab 自带 OnShow 按文字宽自适应宽度，
    -- 锚点交给 OutfitterFrame 的 XML 链式锚点（BOTTOMRIGHT 串向左）。
    -- QuickSwap 只负责建 Tab4，Tab4 的位置也用同样的链式方式串到 Tab3 左侧。

    -- 命名套装对话框
    api.StripTextures(OutfitterNameOutfitDialog)
    api.CreateBackdrop(OutfitterNameOutfitDialog)
    OutfitterNameOutfitDialogTitle:SetPoint("TOP", 0, -8)

    api.StripTextures(OutfitterNameOutfitDialogName, true, "BACKGROUND")
    api.CreateBackdrop(OutfitterNameOutfitDialogName)
    OutfitterNameOutfitDialogName:SetWidth(165)

    api.SkinDropDown(OutfitterNameOutfitDialogCreateUsing)
    OutfitterNameOutfitDialogCreateUsing:SetPoint("TOPLEFT", OutfitterNameOutfitDialogName, "TOPLEFT", -17, -30)
    OutfitterNameOutfitDialogCreateUsingTitle:SetPoint("RIGHT", OutfitterNameOutfitDialogCreateUsing, "LEFT", 5, 0)

    api.SkinButton(OutfitterNameOutfitDialogDoneButton)
    api.SkinButton(OutfitterNameOutfitDialogCancelButton)

    -- 当前套装下拉
    api.StripTextures(OutfitterCurrentOutfit)
    api.CreateBackdrop(OutfitterCurrentOutfit)
    OutfitterCurrentOutfit:SetWidth(140)

    -- 物品行内控件：下拉箭头 / 勾选框 / 分类展开按钮
    for i = 0, 13 do
        local m = getglobal("OutfitterItem" .. i .. "OutfitMenu")
        api.SkinArrowButton(m, "down")

        local cb = getglobal("OutfitterItem" .. i .. "OutfitSelected")
        skin_checkbox(api, cb)

        local c = getglobal("OutfitterItem" .. i .. "CategoryExpand")
        api.SkinCollapseButton(c)
        c.icon.backdrop:SetPoint("TOPLEFT", -2, 1)
        c.icon.backdrop:SetPoint("BOTTOMRIGHT", 1, -2)
    end

    -- 设置页勾选框
    OutfitterShowMinimapButton:SetPoint("TOPLEFT", 15, -90)
    for _, v in { "ShowMinimapButton", "RememberVisibility", "ShowHotkeyMessages", "ShowCurrentOutfit", "HideDisabledOutfits" } do
        local cb = getglobal("Outfitter" .. v)
        skin_checkbox(api, cb)
    end

    -- 部位启用勾选框（快捷换装配置页网格）
    for _, v in { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" } do
        local cb = getglobal("OutfitterEnable" .. v .. "Slot")
        skin_checkbox(api, cb)
    end

    -- 快捷换装页勾选框（QuickSwap.lua 在文件加载期创建，本模块在其后加载，
    -- ADDON_LOADED/PLAYER_LOGIN 时均已存在）
    -- 面板开关（命中区右侧到文字末尾 -140，与 QuickSwap.lua 建框时一致）
    for _, v in { "Enabled", "Compact", "PopupUp", "TinyTooltip", "CooldownCount", "ShowHotKeys" } do
        skin_qs_checkbox(api, getglobal("OutfitterQuickSwapOpt" .. v), -140)
    end

    -- 部位网格（命中区右侧 -60；cSlots 共 18 个部位）
    for i = 1, 18 do
        skin_qs_checkbox(api, getglobal("OutfitterQuickSwapCfg" .. i), -60)
    end

    -- 快捷换装装备槽/弹出列表按钮（TrinketMenu 皮肤同款：图标微缩满铺 +
    -- 深色细边框 backdrop）。按钮懒创建：若在 pfUI 就绪前已建（走的是经典
    -- 边框环分支），这里补皮；已有 backdrop 的跳过，新按钮由创建期直接生效
    for _, prefix in { "OutfitterQuickSwapSlot", "OutfitterQuickSwapItem" } do
        for i = 1, 40 do
            local btn = getglobal(prefix .. i)
            if btn and not btn.backdrop then
                OutfitterQuickSwap_SkinButtonPFUI(btn)
            end
        end
    end

    -- 快速换装面板：pfUI 深色背景板 + pfUI 关闭按钮
    -- 面板自带的经典 tooltip 底永久置透明，可见背景由 frame.backdrop 承担；
    -- 普通/精简模式的背景显隐由 QuickSwap.lua ApplyPanelStyle 切换 backdrop
    local qsFrame = getglobal("OutfitterQuickSwapFrame")
    if qsFrame and not qsFrame.backdrop then
        api.CreateBackdrop(qsFrame)
        qsFrame:SetBackdropColor(0, 0, 0, 0)
        qsFrame:SetBackdropBorderColor(0, 0, 0, 0)
        if gOutfitterQuickSwap_Settings and gOutfitterQuickSwap_Settings.Compact then
            qsFrame.backdrop:Hide()
        end
    end

    local qsClose = getglobal("OutfitterQuickSwapClose")
    if qsClose and not qsClose.pfSkinned then
        api.SkinCloseButton(qsClose, qsFrame, -4, -4)
        qsClose.pfSkinned = true
    end

    -- 分栏2（饰品模式第二栏）：同款 pfUI 深色板；经典 tooltip 底永久置透明，
    -- 背景显隐由 QuickSwap.lua ApplyPanelStyle 切 backdrop（精简 Hide / 普通 Show）
    local qsFrame2 = getglobal("OutfitterQuickSwapFrame2")
    if qsFrame2 and not qsFrame2.backdrop then
        api.CreateBackdrop(qsFrame2)
        qsFrame2:SetBackdropColor(0, 0, 0, 0)
        qsFrame2:SetBackdropBorderColor(0, 0, 0, 0)
        if gOutfitterQuickSwap_Settings and gOutfitterQuickSwap_Settings.Compact then
            qsFrame2.backdrop:Hide()
        end
    end

    -- 角色界面 QuickSlots 弹框（点击纸娃娃装备槽弹出）：应用 pfUI 美化
    -- + SetScript 包装 OnShow，每次打开重刷按钮皮肤（ContainerFrame_Update
    -- 每次 SetSlotToBag 会重置 Border 显隐 / 贴图，必须重刷）
    OutfitterQuickSlots_RefreshSkinPFUI()
    local qsPopup = getglobal("OutfitterQuickSlots")
    if qsPopup and not qsPopup._pfQSOnShowWrapped then
        local _qsOrigOnShow = qsPopup:GetScript("OnShow")
        qsPopup:SetScript("OnShow", function()
            if _qsOrigOnShow and type(_qsOrigOnShow) == "function" then
                _qsOrigOnShow()
            end
            OutfitterQuickSlots_RefreshSkinPFUI()
        end)
        qsPopup._pfQSOnShowWrapped = true
    end

    -- 自动排队设置窗口（懒创建，存在则补皮；不存在时空操作）
    OutfitterQuickSwap_QueueCfgSkin()

    return true
end

-- 等待 pfUI 就绪后应用皮肤（ADDON_LOADED 后 pfUI 可能尚未完成初始化，
-- 再挂 PLAYER_LOGIN 兜底；ApplySkin 成功后注销事件）。
-- 兜底 2：PLAYER_LOGIN 时 pfUI 仍未就绪（新角色首次登录时序不稳实测会出现），
-- 原设计两个触发时机都已消耗、皮肤整个会话不再应用 → 残留经典背景框。
-- 改为 Outfitter 加载完成后，任何后续 ADDON_LOADED 都重试（ApplySkin 内部
-- 全部带 not backdrop / not pfSkinned 幂等守卫，可安全重复调用）
local outfitterLoaded = false
local skinner = CreateFrame("Frame")
skinner:RegisterEvent("ADDON_LOADED")
skinner:RegisterEvent("PLAYER_LOGIN")
skinner:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 == "Outfitter" then
            outfitterLoaded = true
        elseif not outfitterLoaded then
            return  -- Outfitter 框体还不存在，过早应用会引用 nil 全局
        end
    end
    if ApplySkin() then
        this:UnregisterAllEvents()
    end
end)
