local re = re
local sdk = sdk
local d2d = d2d
local imgui = imgui
local log = log
local json = json
local draw = draw

local Core = require("_CatLib")
local Draw = require("_CatLib.draw")

local function FillRect(x, y, w, h, color)
	if d2d then
		d2d.filled_rect(x, y, w, h, color)
	else
		draw.filled_rect(x, y, w, h, Draw.ReverseRGB(color))
	end
end

local function OutlineRect(x, y, w, h, thickness, color)
	if d2d then
		d2d.outline_rect(x, y, w, h, thickness, color)
	else
		draw.outline_rect(x, y, w, h, Draw.ReverseRGB(color))
	end
end

local function Text(text, x, y, color)
	if d2d then
		d2d.text(Core.LoadD2dFont(), text, x, y, color)
	else
		draw.text(text, x, y, Draw.ReverseRGB(color))
	end
end

local function DrawDPS(data, config)
    if not data or not config then return end

    local posX = config.DPS.PosX
    local posY = config.DPS.PosY

    local width = config.DPS.Width
    local rowHeight = config.DPS.RowHeight

    local rowDirection = 1
    if config.DPS.FromDownToTop then
        local rowDirection = -1
    end

    -----------
    -- Title --
    -----------
    -- Quest Time
    local questTime = data.QuestTime
    local min = math.floor(questTime / 60)
    local secs = math.floor(questTime % 60)
    local questTimeText = string.format("%d:%d", min, secs)

    -- Enemy Names
    local enemyNames = data.EnemyNames
    local enemyText = ""
    for enemy, name in pairs(data.EnemyNames) do
        enemyText = enemyText .. name
        if config.DPS.DisplayEnemyHpPercentage then
            local hpData = data.EnemyData[enemy]
            if hpData then
                local percentage = Core.FloatFixed1(hpData.HP/hpData.MaxHP*100)
                enemyText = enemyText .. " (" .. percentage .. "%), "
            end
        end
    end

    if enemyText == "" then
        enemyNames = "NONE"
    end

    Text(questTimeText .. " - " .. enemyText, posX + 1, posY, config.DPS.Colors.Title)

    ------------
    -- Header --
    ------------
    local headerPosX = posX
    posY = posY + rowHeight
    FillRect(headerPosX, posY, width, rowHeight, config.DPS.Colors.Bg)
    local attackerNameType = "ID"
    if config.DPS.ShowHRMR then
        attackerNameType = data.RankType
    end
    Text(attackerNameType, headerPosX, posY, config.DPS.Colors.Columns[0])
    headerPosX = headerPosX + config.DPS.ColumnsWidth[0]

    for i, columnName in ipairs(config.DPS.Columns) do
        if i == 0 then
            goto continue
        end
        Text(columnName, headerPosX, posY, config.DPS.Colors.Columns[i])
        headerPosX = headerPosX + config.DPS.ColumnsWidth[i]
        ::continue::
    end

    ----------
    -- Data --
    ----------
    if data.DamageData ~= nil then
        local total = data.DamageData.Total
        local all =  data.DamageData.All
        local currentPercentag = total / all * 100
        posY = posY + rowHeight

        local i = 1

        for attacker, record in pairs(data.DamageData.Record) do
            headerPosX = posX
            Text(data.Attacker[attacker][attackerNameType], headerPosX, posY, config.DPS.Colors.Columns[0])
            headerPosX = headerPosX + config.DPS.ColumnsWidth[0]

            for j, dmgType in ipairs(config.DPS.Columns) do
                local dmg = record[dmgType]
                local attackPercentage = dmg / all
                Text(tostring(dmg), headerPosX, posY, config.DPS.Colors.Columns[j])
                headerPosX = headerPosX + config.DPS.ColumnsWidth[j]
            end
            posY = posY + rowHeight
            i = i+1
        end
    end
end

return {
    DrawDPS = DrawDPS,
}