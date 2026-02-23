## Load Library
```luau
local Xuilan = loadstring(game:HttpGet("https://raw.githubusercontent.com/XuilanDev/SimpleUi/refs/heads/main/lib.lua"))()
```
## Create Window
```luau
local Window = Xuilan:CreateWindow({
    Title = "Window Title",
    TitleFont = "SourceSansBold",
    TitleColor = "255,255,255",

    Description = "Window Description",
    DescriptionFont = "SourceSans",
    DescriptionColor = "200,200,200",

    Icon = "ASSET_ID",
    ThemeSection = true,
    DefaultTheme = "Cyber",
    BackgroundImage = "ASSET_ID"
})
```
## Add Key System
```luau
Window:AddKeySystem({
    Key = "YourKey",
    TextColor = "255,255,255",
    BackgroundImage = "ASSET_ID",
    BackgroundImageTransparency = 0.8,
    YOffset = 0,
    Buttons = {
        {
            Text = "Get Key",
            CopyContent = "https://link.com",
            TextColor = "255,255,255",
            BackgroundColor = "60,60,80",
            BackgroundTransparency = 0.1,
            Icon = "ASSET_ID"
        }
    }
})
```
