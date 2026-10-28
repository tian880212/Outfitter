if GetLocale() == "zhCN" then

-- 主标题与版本
Outfitter_cVersion = "1.5.3";
Outfitter_cTitle = "Outfitter 一键换装";
Outfitter_cTitleVersion = Outfitter_cTitle .. " 1.5.3";

-- 界面标签
Outfitter_cNameLabel = "名称:";
Outfitter_cCreateUsingTitle = "优化:";
Outfitter_cUseCurrentOutfit = "使用当前套装";
Outfitter_cUseEmptyOutfit = "创建空套装";

Outfitter_cOutfitterTabTitle = "一键换装";
Outfitter_cOptionsTabTitle = "设置";
Outfitter_cAboutTabTitle = "关于";

-- 按钮与操作
Outfitter_cNewOutfit = "新建套装";
Outfitter_cRenameOutfit = "重命名套装";

-- 分类
Outfitter_cCompleteOutfits = "完整套装";
Outfitter_cPartialOutfits = "混搭套装";
Outfitter_cAccessoryOutfits = "配件套装";
Outfitter_cSpecialOutfits = "特殊场合";
Outfitter_cOddsNEndsOutfits = "零散物品";

Outfitter_cNormalOutfit = "日常";
Outfitter_cNakedOutfit = "裸体";

-- 预设套装
Outfitter_cFishingOutfit = "钓鱼";
Outfitter_cHerbalismOutfit = "采药";
Outfitter_cMiningOutfit = "采矿";
Outfitter_cSkinningOutfit = "剥皮";
Outfitter_cFireResistOutfit = "火焰抗性";
Outfitter_cNatureResistOutfit = "自然抗性";
Outfitter_cShadowResistOutfit = "暗影抗性";
Outfitter_cArcaneResistOutfit = "奥术抗性";
Outfitter_cFrostResistOutfit = "冰霜抗性";

Outfitter_cArgentDawnOutfit = "银色黎明";
Outfitter_cRidingOutfit = "骑乘";
Outfitter_cDiningOutfit = "进食";
Outfitter_cBattlegroundOutfit = "战场";
Outfitter_cABOutfit = "阿拉希盆地";
Outfitter_cAVOutfit = "奥特兰克山谷";
Outfitter_cWSGOutfit = "战歌峡谷";
Outfitter_cBROutfit = "血环竞技场";      -- 乌龟服
Outfitter_cSGVOutfit = "阳光林地山谷";        -- 乌龟服
Outfitter_cCityOutfit = "主城";
Outfitter_cBossOutfit = "首领怪物";
Outfitter_cLvl63Outfit = "63级+";
Outfitter_cTrashOutfit = "小怪";
Outfitter_cCritterOutfit = "小动物";

Outfitter_cBeastTrashOutfit = "野兽小怪";
Outfitter_cUndeadTrashOutfit = "亡灵小怪";
Outfitter_cDemonTrashOutfit = "恶魔小怪";

-- 骑乘提示
Outfitter_cMountSpeedFormat = "提升速度 (%d+)%%。";
Outfitter_cMountLowFormat = "又慢又稳";         -- 乌龟坐骑
Outfitter_cMountFreeFormat = "骑行技能提高速度";     -- 特殊坐骑

-- 错误提示（关键优化）
Outfitter_cBagsFullError = "一键换装: 无法卸下 %s，因为所有背包已满";
Outfitter_cDepositBagsFullError = "一键换装: 无法存入 %s，因为所有银行背包已满";
Outfitter_cWithdrawBagsFullError = "一键换装: 无法取出 %s，因为所有背包已满";
Outfitter_cItemNotFoundError = "一键换装: 未找到物品 %s";
Outfitter_cItemAlreadyUsedError = "一键换装: 无法将 %s 放入 %s 槽位，因为它已在其他槽位使用";
Outfitter_cAddingItem = "一键换装: 添加 %s 到 %s 套装";
Outfitter_cNameAlreadyUsedError = "错误：该名称已被使用";
Outfitter_cNoItemsWithStatError = "警告：你的物品中没有此属性";

-- 启用/禁用
Outfitter_cEnableAll = "全部启用";
Outfitter_cEnableNone = "全部禁用";

-- 确认弹窗
Outfitter_cConfirmDeleteMsg = "确定删除套装 %s 吗？";
Outfitter_cConfirmUpdateMsg = "确定将套装 %s 更新为当前套装吗？";
Outfitter_cConfirmRebuildMsg = "确定重建套装 %s 吗？";
Outfitter_cRebuild = "重建";
Outfitter_cUpdate = "更新";
Outfitter_cUpdateToCurrent = "更新为当前";

-- 区域名称
Outfitter_cWesternPlaguelands = "西瘟疫之地";
Outfitter_cEasternPlaguelands = "东瘟疫之地";
Outfitter_cStratholme = "斯坦索姆";
Outfitter_cScholomance = "通灵学院";
Outfitter_cNaxxramas = "纳克萨玛斯";
Outfitter_cAlteracValley = "奥特兰克山谷";
Outfitter_cArathiBasin = "阿拉希盆地";
Outfitter_cWarsongGulch = "战歌峡谷";
Outfitter_cBloodRing = "血环竞技场";           -- 乌龟服
Outfitter_cSunnygladeValley = "阳光林地山谷";           -- 乌龟服
Outfitter_cIronforge = "铁炉堡";
Outfitter_cCityOfIronforge = "铁炉堡";
Outfitter_cDarnassus = "达纳苏斯";
Outfitter_cStormwind = "暴风城";
Outfitter_cOrgrimmar = "奥格瑞玛";
Outfitter_cThunderBluff = "雷霆崖";
Outfitter_cUndercity = "幽暗城";

-- 副本
Outfitter_cAQ20 = "安其拉废墟";
Outfitter_cAQ40 = "安其拉神殿";
Outfitter_cZG = "祖尔格拉布";
Outfitter_cES = "翡翠圣殿";                    -- 乌龟服
Outfitter_cBM = "黑色沼泽";                    -- 乌龟服
Outfitter_cK40 = "荒芜巨岩";                    -- 乌龟服

-- 特殊物品
Outfitter_cFishingPole = "鱼竿";
Outfitter_cStrongFishingPole = "强化钓鱼竿";
Outfitter_cDarkwoodFishingPole = "暗木鱼竿";
Outfitter_cBigIronFishingPole = "粗铁鱼竿";
Outfitter_cBlumpFishingPole = "布拉普家族鱼竿";
Outfitter_cNatPaglesFishingPole = "纳特·帕格的超级钓鱼竿FC-5000型";
Outfitter_cArcaniteFishingPole = "奥金钓鱼竿";
Outfitter_cBarkskinFisher = "树皮鱼竿";       -- 乌龟服

Outfitter_cArgentDawnCommission = "银色黎明委任徽章";
Outfitter_cSealOfTheDawn = "黎明之印";
Outfitter_cRuneOfTheDawn = "黎明符文";

Outfitter_cWhipOfEncouragement = "鞭笞马鞭";   -- 乌龟服
Outfitter_cGoblinCarKey = "地精赛车钥匙";       -- 乌龟服
Outfitter_cGnomeCarKey = "侏儒赛车钥匙";        -- 乌龟服
Outfitter_cCarrotOnAStick = "棍子上的胡萝卜";

-- 属性格式（用于扫描）
Outfitter_cItemStatFormats = {
    { Format = "耐力 %+(%d+)", Types = { "Stamina" } },
    { Format = "智力 %+(%d+)", Types = { "Intellect" } },
    { Format = "敏捷 %+(%d+)", Types = { "Agility" } },
    { Format = "力量 %+(%d+)", Types = { "Strength" } },
    { Format = "精神 %+(%d+)", Types = { "Spirit" } },
    { Format = "护甲 %+(%d+)", Types = { "Armor" } },
    { Format = "防御 %+(%d+)", Types = { "Defense" } },
    { Format = "防御技能 %+(%d+)", Types = { "Defense" } },

    { Format = "%+(%d+) 耐力", Types = { "Stamina" } },
    { Format = "%+(%d+) 智力", Types = { "Intellect" } },
    { Format = "%+(%d+) 敏捷", Types = { "Agility" } },
    { Format = "%+(%d+) 力量", Types = { "Strength" } },
    { Format = "%+(%d+) 精神", Types = { "Spirit" } },
    { Format = "(%d+) 护甲", Types = { "Armor" } },
    { Format = "%+(%d+) 攻击强度", Types = { "Attack" } },

    { Format = "所有属性 %+(%d+)", Types = { "Stamina", "Intellect", "Agility", "Strength", "Spirit" } },

    { Format = "法力值 %+(%d+)", Types = { "Mana" } },
    { Format = "生命值 %+(%d+)", Types = { "Health" } },

    { Format = "%+(%d+) 每5秒法力回复。", Types = { "ManaRegen" } },
    { Format = "每5秒回复(%d+)点法力值。", Types = { "ManaRegen" } },

    { Format = "%+(%d+) 每5秒生命回复。", Types = { "HealthRegen" } },
    { Format = "每5秒回复(%d+)点生命值。", Types = { "HealthRegen" } },
    { Format = "每5秒恢复(%d+)点生命值。", Types = { "HealthRegen" } },

    {Format = "坐骑速度提高", Value = 3, Types = {"Riding"}},
    { Format = "秘银马刺", Value = 3, Types = { "Riding" } },
    { Format = "瑟银马刺", Value = 5, Types = { "Riding" } },

    { Format = "%+(%d+) 火焰抗性", Types = { "FireResist" } },
    { Format = "%+(%d+) 自然抗性", Types = { "NatureResist" } },
    { Format = "%+(%d+) 冰霜抗性", Types = { "FrostResist" } },
    { Format = "%+(%d+) 暗影抗性", Types = { "ShadowResist" } },
    { Format = "%+(%d+) 奥术抗性", Types = { "ArcaneResist" } },
    { Format = "%+(%d+) 所有抗性", Types = { "FireResist", "NatureResist", "FrostResist", "ShadowResist", "ArcaneResist" } },

    { Format = "武器伤害 %+(%d+)", Types = { "MeleeDmg" } },
    { Format = "命中几率提高(%d+)%%", Types = { "MeleeHit" } },
    { Format = "致命一击几率提高(%d+)%%", Types = { "MeleeCrit" } },
    { Format = "躲闪攻击几率提高(%d+)%%", Types = { "Dodge" } },
    { Format = "伤害 %+(%d+)", Types = { "MeleeDmg" } },
    { Format = "(%d+) 格挡", Types = { "Block" } },
    { Format = "格挡值 %+(%d+)", Types = { "Block" } },
    { Format = "盾牌格挡值提高(%d+)", Types = { "Block" } },

    { Format = "钓鱼技能提高 %+(%d+)%%。", Types = { "Fishing" } },
    { Format = "钓鱼 %+(%d+)", Types = { "Fishing" } },
    { Format = "草药学 %+(%d+)", Types = { "Herbalism" } },
    { Format = "挖矿 %+(%d+)", Types = { "Mining" } },
    { Format = "剥皮 %+(%d+)", Types = { "Skinning" } },

    -- 新增：采药/采矿特殊物品
    { Format = "提高采集黑莲花的几率", Value = 1, Types = { "Herbalism" } },
    { Format = "提高挖到奥术水晶的几率", Value = 1, Types = { "Mining" } },
    
    -- 新增：触发几率词缀
    { Format = "使你触发装备物品效果的几率提高(%d+)%%", Types = { "ProcChance" } },
    { Format = "提高触发装备物品效果的几率(%d+)%%", Types = { "ProcChance" } }, -- 备用格式

    { Format = "法术致命一击几率提高(%d+)%%", Types = { "SpellCrit" } },
    { Format = "法术命中几率提高(%d+)%%", Types = { "SpellHit" } },
    { Format = "法术和魔法效果伤害/治疗最多(%d+)点", Types = { "SpellDmg", "ShadowDmg", "FireDmg", "FrostDmg", "ArcaneDmg", "NatureDmg", "Healing" } },
    { Format = "法术治疗效果最多(%d+)点", Types = { "Healing" } },
    { Format = "治疗法术 %+(%d+)", Types = { "Healing" } },
    { Format = "%+(%d+) 治疗法术", Types = { "Healing" } },

    { Format = "%+(%d+) 火焰法术伤害", Types = { "FireDmg" } },
    { Format = "%+(%d+) 暗影法术伤害", Types = { "ShadowDmg" } },
    { Format = "%+(%d+) 冰霜法术伤害", Types = { "FrostDmg" } },
    { Format = "%+(%d+) 奥术法术伤害", Types = { "ArcaneDmg" } },
    { Format = "%+(%d+) 自然法术伤害", Types = { "NatureDmg" } },

    { Format = "火焰法术和效果伤害最多(%d+)点", Types = { "FireDmg" } },
    { Format = "暗影法术和效果伤害最多(%d+)点", Types = { "ShadowDmg" } },
    { Format = "冰霜法术和效果伤害最多(%d+)点", Types = { "FrostDmg" } },
    { Format = "奥术法术和效果伤害最多(%d+)点", Types = { "ArcaneDmg" } },
    { Format = "自然法术和效果伤害最多(%d+)点", Types = { "NatureDmg" } },

    -- 新增游泳属性识别
    { Format = "游泳速度提高(%d+)%%", Types = { "Swimming" } },
    { Format = "使你可以在水下呼吸", Value = 1, Types = { "Swimming" } },
    { Format = "略微提高奔跑和游泳速度", Value = 8, Types = { "Swimming" } }
};

-- 属性名称
Outfitter_cAgilityStatName = "敏捷";
Outfitter_cArmorStatName = "护甲";
Outfitter_cDefenseStatName = "防御";
Outfitter_cIntellectStatName = "智力";
Outfitter_cSpiritStatName = "精神";
Outfitter_cStaminaStatName = "耐力";
Outfitter_cStrengthStatName = "力量";

Outfitter_cManaRegenStatName = "法力回复";
Outfitter_cHealthRegenStatName = "生命回复";

Outfitter_cSpellCritStatName = "法术暴击";
Outfitter_cSpellHitStatName = "法术命中";
Outfitter_cSpellDmgStatName = "法术伤害";
Outfitter_cFrostDmgStatName = "冰霜伤害";
Outfitter_cFireDmgStatName = "火焰伤害";
Outfitter_cArcaneDmgStatName = "奥术伤害";
Outfitter_cShadowDmgStatName = "暗影伤害";
Outfitter_cNatureDmgStatName = "自然伤害";
Outfitter_cHealingStatName = "治疗";

Outfitter_cMeleeCritStatName = "近战暴击";
Outfitter_cMeleeHitStatName = "近战命中";
Outfitter_cMeleeDmgStatName = "近战伤害";
Outfitter_cAttackStatName = "攻击强度";
Outfitter_cDodgeStatName = "躲闪";

Outfitter_cArcaneResistStatName = "奥术抗性";
Outfitter_cFireResistStatName = "火焰抗性";
Outfitter_cFrostResistStatName = "冰霜抗性";
Outfitter_cNatureResistStatName = "自然抗性";
Outfitter_cShadowResistStatName = "暗影抗性";

Outfitter_cFishingStatName = "钓鱼";
Outfitter_cHerbalismStatName = "草药学";
Outfitter_cMiningStatName = "挖矿";
Outfitter_cSkinningStatName = "剥皮";
Outfitter_cProcChanceStatName = "触发几率";   -- 新增

-- 设置界面
Outfitter_cOptionsTitle = "一键换装设置";
Outfitter_cShowMinimapButton = "显示小地图按钮";
Outfitter_cShowMinimapButtonOnDescription = "勾选以在小地图显示按钮";
Outfitter_cShowMinimapButtonOffDescription = "取消勾选以隐藏按钮";
Outfitter_cRememberVisibility = "记住披风和头盔显示状态";
Outfitter_cRememberVisibilityOnDescription = "勾选以独立控制每个套装的披风/头盔";
Outfitter_cRememberVisibilityOffDescription = "取消以统一控制所有套装";
Outfitter_cShowHotkeyMessages = "显示快捷键换装提示";
Outfitter_cShowHotkeyMessagesOnDescription = "取消以隐藏快捷键换装消息";
Outfitter_cShowHotkeyMessagesOffDescription = "勾选以显示快捷键换装消息";
Outfitter_cShowCurrentOutfit = "在小窗口显示当前套装";
Outfitter_cHideDisabledOutfits = "从列表隐藏已禁用套装";

-- 换装提示
Outfitter_cEquipOutfitMessageFormat = "一键换装: 已装备 %s";
Outfitter_cUnequipOutfitMessageFormat = "一键换装: 已卸下 %s";

-- 关于
Outfitter_cAboutTitle = "关于一键换装";
Outfitter_cAuthor = "原作者：Outfitter Team";
Outfitter_cTestersTitle = "乌龟服定制汉化版";
Outfitter_cTestersNames = "Sunelegy 汉化适配";
Outfitter_cSpecialThanksTitle = "特别感谢：";
Outfitter_cSpecialThanksNames = "欧服 Azshara 公会测试支持";
Outfitter_cGuildURL = "适配版本：1.18.0";
Outfitter_cGuildURL2 = "欢迎分享与反馈";

Outfitter_cOpenOutfitter = "打开一键换装";

-- 套装描述
Outfitter_cArgentDawnOutfitDescription = "进入瘟疫之地时自动装备该套装";
Outfitter_cRidingOutfitDescription = "骑乘坐骑时自动装备该套装";
Outfitter_cDiningOutfitDescription = "进食或饮水时自动装备该套装";
Outfitter_cBattlegroundOutfitDescription = "进入任意战场时自动装备该套装";
Outfitter_cArathiBasinOutfitDescription = "进入阿拉希盆地时自动装备该套装";
Outfitter_cAlteracValleyOutfitDescription = "进入奥特兰克山谷时自动装备该套装";
Outfitter_cWarsongGulchOutfitDescription = "进入战歌峡谷时自动装备该套装";
Outfitter_cBloodRingOutfitDescription = "进入血环竞技场时自动装备该套装";
Outfitter_cSunnygladeValleyOutfitDescription = "进入阳光林地山谷时自动装备该套装";
Outfitter_cCityOutfitDescription = "进入主城时自动装备该套装";
Outfitter_cBossOutfitDescription = "目标为63级以上首领怪物时自动装备该套装";
Outfitter_cLvl63OutfitDescription = "目标为63级以上怪物时自动装备该套装";
Outfitter_cTrashOutfitDescription = "目标为63级以下小怪时自动装备该套装";
Outfitter_cCritterOutfitDescription = "目标为小动物时自动装备该套装";
Outfitter_cBeastTrashOutfitDescription = "目标为63级以下野兽小怪时自动装备该套装";
Outfitter_cUndeadTrashOutfitDescription = "目标为63级以下亡灵小怪时自动装备该套装";
Outfitter_cDemonTrashOutfitDescription = "目标为63级以下恶魔小怪时自动装备该套装";

-- 新增游泳套装
Outfitter_cSwimmingOutfit = "游泳";
Outfitter_cSwimmingOutfitDescription = "当你游泳时自动装备该套装";

-- 按键绑定
Outfitter_cKeyBinding = "按键绑定";
BINDING_HEADER_OUTFITTER_TITLE = Outfitter_cTitle;
BINDING_NAME_OUTFITTER_OUTFIT1  = "套装 1";
BINDING_NAME_OUTFITTER_OUTFIT2  = "套装 2";
BINDING_NAME_OUTFITTER_OUTFIT3  = "套装 3";
BINDING_NAME_OUTFITTER_OUTFIT4  = "套装 4";
BINDING_NAME_OUTFITTER_OUTFIT5  = "套装 5";
BINDING_NAME_OUTFITTER_OUTFIT6  = "套装 6";
BINDING_NAME_OUTFITTER_OUTFIT7  = "套装 7";
BINDING_NAME_OUTFITTER_OUTFIT8  = "套装 8";
BINDING_NAME_OUTFITTER_OUTFIT9  = "套装 9";
BINDING_NAME_OUTFITTER_OUTFIT10 = "套装 10";

-- 禁用
Outfitter_cDisableOutfit = "禁用套装";
Outfitter_cDisableOutfitInBG = "战场中禁用套装";
Outfitter_cDisableOutfitInInstance = "副本中禁用套装";
Outfitter_cDisabledOutfitName = "%s (已禁用)";

-- 小地图按钮
Outfitter_cMinimapButtonTitle = "一键换装";
Outfitter_cMinimapButtonDescription = "点击选择不同套装，或拖动重新定位按钮。";

-- 职业与姿态
Outfitter_cDruidClassName = "德鲁伊";
Outfitter_cHunterClassName = "猎人";
Outfitter_cMageClassName = "法师";
Outfitter_cPaladinClassName = "圣骑士";
Outfitter_cPriestClassName = "牧师";
Outfitter_cRogueClassName = "盗贼";
Outfitter_cShamanClassName = "萨满祭司";
Outfitter_cWarlockClassName = "术士";
Outfitter_cWarriorClassName = "战士";

Outfitter_cBattleStance = "战斗姿态";
Outfitter_cDefensiveStance = "防御姿态";
Outfitter_cBerserkerStance = "狂暴姿态";

Outfitter_cWarriorBattleStance = "战士: 战斗姿态";
Outfitter_cWarriorDefensiveStance = "战士: 防御姿态";
Outfitter_cWarriorBerserkerStance = "战士: 狂暴姿态";

Outfitter_cBearForm = "熊形态";
Outfitter_cCatForm = "猎豹形态";
Outfitter_cAquaticForm = "水栖形态";
Outfitter_cTravelForm = "旅行形态";
Outfitter_cDireBearForm = "巨熊形态";
Outfitter_cMoonkinForm = "枭兽形态";

Outfitter_cGhostWolfForm = "幽魂之狼";
Outfitter_cStealth = "潜行";

Outfitter_cDruidBearForm = "德鲁伊: 熊形态";
Outfitter_cDruidCatForm = "德鲁伊: 猎豹形态";
Outfitter_cDruidAquaticForm = "德鲁伊: 水栖形态";
Outfitter_cDruidTravelForm = "德鲁伊: 旅行形态";
Outfitter_cDruidMoonkinForm = "德鲁伊: 枭兽形态";

Outfitter_cPriestShadowform = "牧师: 暗影形态";
Outfitter_cRogueStealth = "盗贼: 潜行";
Outfitter_cShamanGhostWolf = "萨满祭司: 幽魂之狼";

Outfitter_cHunterMonkey = "猎人: 灵猴守护";
Outfitter_cHunterHawk = "猎人: 雄鹰守护";
Outfitter_cHunterCheetah = "猎人: 猎豹守护";
Outfitter_cHunterPack = "猎人: 豹群守护";
Outfitter_cHunterBeast = "猎人: 野兽守护";
Outfitter_cHunterWild = "猎人: 野性守护";
Outfitter_cHunterWolf = "猎人: 孤狼守护";
Outfitter_cHunterViper = "猎人: 蝰蛇守护";

Outfitter_cMageEvocate = "法师: 唤醒";

Outfitter_cAspectOfTheCheetah = "猎豹守护";
Outfitter_cAspectOfThePack = "豹群守护";
Outfitter_cAspectOfTheBeast = "野兽守护";
Outfitter_cAspectOfTheWild = "野性守护";
Outfitter_cAspectOfTheWolf = "孤狼守护";
Outfitter_cAspectOfTheViper = "蝰蛇守护";
Outfitter_cEvocate = "唤醒";

Outfitter_cCritter = "小动物";

-- 分类描述
Outfitter_cCompleteCategoryDescription = "完整套装指定了所有槽位的物品，装备时会替换其他所有套装。";
Outfitter_cPartialCategoryDescription = "混搭套装仅指定部分槽位。装备时，它们会叠加在完整套装之上，替换其他混搭或配件套装。";
Outfitter_cAccessoryCategoryDescription = "配件套装仅指定部分槽位。你可以同时选择多个配件套装，它们会结合叠加在完整和混搭套装之上。";
Outfitter_cSpecialCategoryDescription = "特殊场合套装会在特定场合自动装备，覆盖其他所有套装。";
Outfitter_cOddsNEndsCategoryDescription = "零散物品是未在任何套装中使用过的物品清单。有助于确保使用所有物品或不携带多余物品。";

Outfitter_cRebuildOutfitFormat = "重建 %s";

Outfitter_cTranslationCredit = "汉化：Sunelegy";

-- 槽位设置
Outfitter_cSlotEnableTitle = "启用槽位";
Outfitter_cSlotEnableDescription = "勾选后，切换套装时会装备该槽位物品。如果未勾选，该槽位不会被修改。";

Outfitter_cFinger0SlotName = "第一戒指";
Outfitter_cFinger1SlotName = "第二戒指";
Outfitter_cTrinket0SlotName = "第一饰品";
Outfitter_cTrinket1SlotName = "第二饰品";

-- 银行操作
Outfitter_cOutfitCategoryTitle = "分类";
Outfitter_cBankCategoryTitle = "银行";
Outfitter_cDepositToBank = "存入银行（全部）";
Outfitter_cDepositUniqueToBank = "存入银行（唯一物品）";
Outfitter_cWithdrawFromBank = "从银行取出";

Outfitter_cMissingItemsLabel = "缺失物品：";
Outfitter_cBankedItemsLabel = "银行物品：";

-- 修理
Outfitter_cRepairAllBags = "一键换装: 修理所有背包物品";

-- 统计分类
Outfitter_cStatsCategory = "属性";
Outfitter_cMeleeCategory = "近战";
Outfitter_cSpellsCategory = "治疗与法术";
Outfitter_cRegenCategory = "回复";
Outfitter_cResistCategory = "抗性";
Outfitter_cTradeCategory = "商业技能";

Outfitter_cTankPoints = "坦克点数";
Outfitter_cCustom = "自定义";

Outfitter_cRequiresHerbalism = "需要草药学";
Outfitter_cRequiresSkinning = "需要剥皮";
Outfitter_cRequiresMining = "需要挖矿";
Outfitter_cAutoEquip = "自动装备";
Outfitter_cAutoUnEquip = "自动卸下";

end