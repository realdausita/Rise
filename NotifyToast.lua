if getgenv().NotifyToast then return end

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local Config = {
    ["Slide In Time"] = 0.4,
    ["Slide Out Time"] = 0.05,
    ["Scale Time"] = 0.11,
    ["Scale Down"] = 0.96,
    ["Start Y"] = -1,
    ["End Y"] = 59,
    ["Default Duration"] = 2,
    ["Background Color"] = Color3.fromHex("#23262C"),
    ["Text Color"] = Color3.fromRGB(247,247,248),
    ["Width Offset"] = -24,
    ["Title Size"] = 20,
    ["Subtitle Size"] = 15,
    ["Icon Size"] = 36,
    ["Icon Text Size"] = 26,
    ["Remove Previous"] = false,
    ["Corner Radius"] = 6,
    ["Min Height"] = 60,
    ["Thumb Size"] = 150
}

local ThumbTypes = {
    ["Asset"] = { w = 150, h = 150, type = "Asset" },
    ["Avatar"] = { w = 150, h = 150, type = "Avatar" },
    ["Avatar Bust"] = { w = 150, h = 150, type = "AvatarBust" },
    ["Avatar Head Shot"] = { w = 150, h = 150, type = "AvatarHeadShot" },
    ["Badge Icon"] = { w = 150, h = 150, type = "BadgeIcon" },
    ["Bundle Thumbnail"] = { w = 150, h = 150, type = "BundleThumbnail" },
    ["Font Family"] = { w = 150, h = 150, type = "FontFamily" },
    ["Game Icon"] = { w = 150, h = 150, type = "GameIcon" },
    ["Game Pass"] = { w = 150, h = 150, type = "GamePass" },
    ["Game Thumbnail"] = { w = 256, h = 144, type = "GameThumbnail" },
    ["Group Icon"] = { w = 150, h = 150, type = "GroupIcon" },
    ["Outfit"] = { w = 150, h = 150, type = "Outfit" },
}

local ThumbTypeAliases = {
    ["Asset"] = "Asset",
    ["Image"] = "Asset",
    ["Decal"] = "Asset",
    ["Audio"] = "Asset",
    ["Mesh"] = "Asset",
    ["Model"] = "Asset",
    ["Animation"] = "Asset",
    ["Video"] = "Asset",
    ["Plugin"] = "Asset",
    ["Tshirt"] = "Asset",
    ["Shirt"] = "Asset",
    ["Pants"] = "Asset",
    ["Hat"] = "Asset",
    ["Accessory"] = "Asset",
    ["Face"] = "Asset",
    ["Head"] = "Asset",
    ["Gear"] = "Asset",
    ["Avatar"] = "Avatar",
    ["User"] = "Avatar",
    ["Player"] = "Avatar",
    ["Avatar Bust"] = "Avatar Bust",
    ["Bust"] = "Avatar Bust",
    ["Avatar Head Shot"] = "Avatar Head Shot",
    ["Headshot"] = "Avatar Head Shot",
    ["Badge"] = "Badge Icon",
    ["Badge Icon"] = "Badge Icon",
    ["Bundle"] = "Bundle Thumbnail",
    ["Bundle Thumbnail"] = "Bundle Thumbnail",
    ["Font"] = "Font Family",
    ["Font Family"] = "Font Family",
    ["Game"] = "Game Icon",
    ["Game Icon"] = "Game Icon",
    ["Experience"] = "Game Icon",
    ["Game Pass"] = "Game Pass",
    ["Pass"] = "Game Pass",
    ["Game Thumbnail"] = "Game Thumbnail",
    ["Place"] = "Game Thumbnail",
    ["Group"] = "Group Icon",
    ["Group Icon"] = "Group Icon",
    ["Outfit"] = "Outfit",
}

local currentToast = nil
local imageCounter = 0

local function ensureFolder(path)
    pcall(function()
        if not isfolder(path) then
            makefolder(path)
        end
    end)
end

local function autoDeleteFile(filepath)
    task.delay(10, function()
        pcall(function()
            if isfile(filepath) then
                delfile(filepath)
            end
        end)
    end)
end

local function toNumberId(value)
    if type(value) == "number" then
        return math.floor(value)
    end
    if type(value) ~= "string" then
        return nil
    end
    local n = value:match("(%d+)")
    return n and tonumber(n) or nil
end

local function normalizeThumbType(thumbType)
    if type(thumbType) ~= "string" or thumbType == "" then
        return nil
    end
    if ThumbTypes[thumbType] then
        return thumbType
    end
    local normalized = thumbType:lower():gsub("[%s_%-]", "")
    for aliasKey, canonical in pairs(ThumbTypeAliases) do
        if aliasKey:lower():gsub("[%s_%-]", "") == normalized then
            return canonical
        end
    end
    return nil
end

local function makeRbxThumb(thumbType, id, size)
    local info = ThumbTypes[thumbType]
    if not info or not id then
        return nil
    end
    local rbxType = info.type or thumbType:gsub("%s", "")
    local w, h = info.w, info.h
    if type(size) == "number" then
        w, h = size, size
    elseif type(size) == "table" then
        w = size.w or size.x or size[1] or w
        h = size.h or size.y or size[2] or h
    end
    return string.format("rbxthumb://type=%s&id=%d&w=%d&h=%d", rbxType, id, w, h)
end

local function extractIdFromRobloxUrl(url)
    local id = url:match("roblox%.com/[^%s]*%a+/(%d+)")
        or url:match("[?&]id=(%d+)")
        or url:match("/asset/%?id=(%d+)")
    return id and tonumber(id) or nil
end

local function inferThumbTypeFromUrl(url)
    local lower = url:lower()
    if lower:match("/users/") or lower:match("/user%.aspx") or lower:match("userid=") then
        return "Avatar Head Shot"
    end
    if lower:match("/groups/") or lower:match("groupid=") then
        return "Group Icon"
    end
    if lower:match("/badges/") or lower:match("badgeid=") then
        return "Badge Icon"
    end
    if lower:match("/game%-pass") or lower:match("/gamepass") or lower:match("gamepass") then
        return "Game Pass"
    end
    if lower:match("/bundles/") then
        return "Bundle Thumbnail"
    end
    if lower:match("/games/") or lower:match("/experiences/") then
        return "Game Icon"
    end
    return "Asset"
end

local function isContentScheme(value)
    if type(value) ~= "string" then
        return false
    end
    return value:match("^rbxassetid://")
        or value:match("^rbxasset://")
        or value:match("^rbxthumb://")
        or value:match("^rbxgameasset://")
        or value:match("^rbxhttp://")
        or value:match("^rbxalias://")
end

local function isHttpUrl(value)
    return type(value) == "string" and value:match("^https?://") ~= nil
end

local function isRobloxHost(url)
    return url:lower():match("roblox%.com") ~= nil
        or url:lower():match("rbxcdn%.com") ~= nil
end

local function resolveIconContent(config)
    local icon = config.icon
    local thumbType = normalizeThumbType(config.iconType or config.thumbType or config.assetType or config.AssetType)
    local thumbSize = config.iconThumbSize or config.thumbSize or Config["Thumb Size"]

    if type(icon) == "number" then
        if thumbType then
            return makeRbxThumb(thumbType, icon, thumbSize)
        end
        return "rbxassetid://" .. tostring(icon)
    end

    if type(icon) ~= "string" then
        return nil, "text"
    end

    if isContentScheme(icon) then
        if thumbType then
            local id = toNumberId(icon)
            local built = id and makeRbxThumb(thumbType, id, thumbSize)
            if built then
                return built
            end
        end
        return icon
    end

    if isHttpUrl(icon) then
        if isRobloxHost(icon) then
            local id = extractIdFromRobloxUrl(icon)
            local inferred = thumbType or inferThumbTypeFromUrl(icon)
            if id then
                return makeRbxThumb(inferred, id, thumbSize)
            end
        end
        return icon, "url"
    end

    if icon:match("^%d+$") then
        local id = tonumber(icon)
        if thumbType then
            return makeRbxThumb(thumbType, id, thumbSize)
        end
        return "rbxassetid://" .. icon
    end

    local looseId = icon:match("rbxassetid:?/*(%d+)") or icon:match("asset/?id=(%d+)")
    if looseId then
        local id = tonumber(looseId)
        if thumbType then
            return makeRbxThumb(thumbType, id, thumbSize)
        end
        return "rbxassetid://" .. looseId
    end

    return icon, "text"
end

local function createImageIcon(image, iconColor)
    local iconObj = Instance.new("ImageLabel")
    iconObj.Name = "ToastIcon"
    iconObj.Image = image
    iconObj.ImageColor3 = iconColor or Color3.new(1, 1, 1)
    iconObj.BackgroundTransparency = 1
    iconObj.Size = UDim2.new(0, Config["Icon Size"], 0, Config["Icon Size"])
    iconObj.ScaleType = Enum.ScaleType.Fit
    iconObj.LayoutOrder = 1
    return iconObj
end

local function loadUrlIcon(url, iconColor)
    local req = http_request or (syn and syn.request) or request
    if not req then
        return createImageIcon(url, iconColor)
    end

    local folderPath = "./temp/img"
    ensureFolder(folderPath)
    imageCounter = imageCounter + 1
    local filename = folderPath .. "/" .. imageCounter .. ".png"
    local success, res = pcall(function()
        return req({ Url = url, Method = "GET" }).Body
    end)
    if success and res then
        writefile(filename, res)
        autoDeleteFile(filename)
        local asset = getcustomasset(filename)
        return createImageIcon(asset, iconColor)
    end
    return nil
end

local function NotifyToast(config)
    config = config or {}

    if Config["Remove Previous"] and currentToast and currentToast.Parent then
        currentToast:Destroy()
    end

    local toastId = "Toast_" .. HttpService:GenerateGUID(false)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = toastId
    screenGui.DisplayOrder = 9
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.AutoLocalize = false
    screenGui.ResetOnSpawn = false
    screenGui.ScreenInsets = Enum.ScreenInsets.None
    screenGui.Parent = CoreGui

    currentToast = screenGui

    local container = Instance.new("TextButton")
    container.Name = "ToastContainer"
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.new(0.5,0,0,Config["Start Y"])
    container.BackgroundTransparency = 1
    container.Text = ""
    container.Parent = screenGui

    local sizeConstraint = Instance.new("UISizeConstraint")
    sizeConstraint.MaxSize = Vector2.new(400, math.huge)
    sizeConstraint.MinSize = Vector2.new(0, Config["Min Height"])
    sizeConstraint.Parent = container

    local bg = Instance.new("Frame")
    bg.Name = "Toast"
    bg.BackgroundColor3 = Config["Background Color"]
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel = 0
    bg.Size = UDim2.new(1,0,1,0)
    bg.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, Config["Corner Radius"])
    corner.Parent = bg

    local innerFrame = Instance.new("Frame")
    innerFrame.BackgroundTransparency = 1
    innerFrame.Size = UDim2.new(1,0,1,0)
    innerFrame.Parent = bg

    local hList = Instance.new("UIListLayout")
    hList.Padding = UDim.new(0,12)
    hList.FillDirection = Enum.FillDirection.Horizontal
    hList.SortOrder = Enum.SortOrder.LayoutOrder
    hList.VerticalAlignment = Enum.VerticalAlignment.Center
    hList.Parent = innerFrame

    local msgFrame = Instance.new("Frame")
    msgFrame.BackgroundTransparency = 1
    msgFrame.Size = UDim2.new(1,0,1,0)
    msgFrame.LayoutOrder = 2
    msgFrame.Parent = innerFrame

    local vList = Instance.new("UIListLayout")
    vList.Padding = UDim.new(0,12)
    vList.SortOrder = Enum.SortOrder.LayoutOrder
    vList.VerticalAlignment = Enum.VerticalAlignment.Center
    vList.Parent = msgFrame

    local textFrame = Instance.new("Frame")
    textFrame.BackgroundTransparency = 1
    textFrame.Size = UDim2.new(1,-48,0,0)
    textFrame.AutomaticSize = Enum.AutomaticSize.Y
    textFrame.Parent = msgFrame

    local vList2 = Instance.new("UIListLayout")
    vList2.SortOrder = Enum.SortOrder.LayoutOrder
    vList2.VerticalAlignment = Enum.VerticalAlignment.Center
    vList2.Parent = textFrame

    local title = Instance.new("TextLabel")
    title.Name = "ToastTitle"
    title.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
    title.TextColor3 = Config["Text Color"]
    title.TextSize = Config["Title Size"]
    title.TextWrapped = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1,0,0,0)
    title.AutomaticSize = Enum.AutomaticSize.Y
    title.RichText = true
    title.LayoutOrder = 1
    title.Parent = textFrame

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "ToastSubtitle"
    subtitle.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json")
    subtitle.TextColor3 = Config["Text Color"]
    subtitle.TextSize = Config["Subtitle Size"]
    subtitle.TextWrapped = true
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(1,0,0,0)
    subtitle.AutomaticSize = Enum.AutomaticSize.Y
    subtitle.RichText = true
    subtitle.LayoutOrder = 2
    subtitle.Parent = textFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0,12)
    padding.PaddingRight = UDim.new(0,12)
    padding.PaddingTop = UDim.new(0,12)
    padding.PaddingBottom = UDim.new(0,12)
    padding.Parent = innerFrame

    local scaler = Instance.new("UIScale")
    scaler.Scale = 1
    scaler.Parent = container

    title.Text = config.title or ""
    subtitle.Text = config.content or config.subtitle or ""

    local duration = config.duration or Config["Default Duration"]
    local callback = config.callback or function() end

    local showIcon = config.icon and config.icon ~= ""
    local iconObj = innerFrame:FindFirstChild("ToastIcon")
    if iconObj then iconObj:Destroy() end

    local iconColor = config.iconColor
    if type(iconColor) == "string" and iconColor:match("^#") then
        iconColor = Color3.fromHex(iconColor)
    end

    if showIcon then
        local content, kind = resolveIconContent(config)

        if kind == "url" then
            iconObj = loadUrlIcon(content, iconColor)
        elseif kind == "text" then
            iconObj = Instance.new("TextLabel")
            iconObj.Name = "ToastIcon"
            iconObj.FontFace = Font.new("rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json", Enum.FontWeight.Bold)
            iconObj.Text = tostring(content or config.icon)
            iconObj.TextColor3 = iconColor or Config["Text Color"]
            iconObj.TextSize = Config["Icon Text Size"]
            iconObj.TextXAlignment = Enum.TextXAlignment.Center
            iconObj.TextYAlignment = Enum.TextYAlignment.Center
            iconObj.BackgroundTransparency = 1
            iconObj.Size = UDim2.new(0, Config["Icon Size"], 0, Config["Icon Size"])
            iconObj.LayoutOrder = 1
        elseif content then
            iconObj = createImageIcon(content, iconColor)
        end

        if iconObj then
            iconObj.Parent = innerFrame

            local radius = config.iconCornerRadius or config.iconRadius or config.IconCorner or config.IconRadius or 0
            if radius ~= 0 then
                local iconCorner = Instance.new("UICorner")
                if radius == true or radius == 0.5 or radius >= 18 then
                    iconCorner.CornerRadius = UDim.new(0.5, 0)
                else
                    iconCorner.CornerRadius = UDim.new(0, radius)
                end
                iconCorner.Parent = iconObj
            end
        end
    end

    local textOffset = showIcon and -48 or 0
    textFrame.Size = UDim2.new(1, textOffset, 0, 0)

    local hasTitle = title.Text ~= ""
    local hasSubtitle = subtitle.Text ~= ""
    title.Visible = hasTitle
    subtitle.Visible = hasSubtitle

    container.Size = UDim2.new(1, Config["Width Offset"], 0, 0)
    container.AutomaticSize = Enum.AutomaticSize.Y
    bg.AutomaticSize = Enum.AutomaticSize.Y
    innerFrame.AutomaticSize = Enum.AutomaticSize.Y
    msgFrame.AutomaticSize = Enum.AutomaticSize.Y

    screenGui.Enabled = true
    container.Position = UDim2.new(0.5,0,0,Config["Start Y"])
    scaler.Scale = 1

    task.wait()

    local actualHeight = container.AbsoluteSize.Y
    local dynamicShowY = Config["End Y"]/2.818 + (actualHeight / 2)

    container.Position = UDim2.new(0.5,0,0,Config["Start Y"])

    TweenService:Create(container, TweenInfo.new(Config["Slide In Time"], Enum.EasingStyle.Quint), {
        Position = UDim2.new(0.5,0,0,dynamicShowY)
    }):Play()

    local function hideToast()
        TweenService:Create(container, TweenInfo.new(Config["Slide Out Time"], Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5,0,0,Config["Start Y"])
        }):Play()
        task.delay(Config["Slide Out Time"], function()
            if currentToast == screenGui then currentToast = nil end
            screenGui:Destroy()
        end)
    end

    task.delay(duration, function()
        if screenGui and screenGui.Parent then
            hideToast()
        end
    end)

    container.MouseButton1Down:Connect(function()
        TweenService:Create(scaler, TweenInfo.new(Config["Scale Time"]), {Scale = Config["Scale Down"]}):Play()
    end)

    container.MouseButton1Up:Connect(function()
        TweenService:Create(scaler, TweenInfo.new(Config["Scale Time"]), {Scale = 1}):Play()
    end)

    container.MouseButton1Click:Connect(function()
        hideToast()
        callback()
    end)

    container.MouseLeave:Connect(function()
        TweenService:Create(scaler, TweenInfo.new(Config["Scale Time"]), {Scale = 1}):Play()
    end)
end

getgenv().NotifyToast = NotifyToast
