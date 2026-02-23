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
    Key = "JeffreyEinstein",
    TextColor = "255,255,255",
    BackgroundImage = "136007050760089",
    BackgroundImageTransparency = 0.85,
    YOffset = 0,

    Buttons = {
        {
            Text = "Get Key 1",
            CopyContent = "https://link1.com",
            TextColor = "255,255,255",
            BackgroundColor = "60,60,80",
            BackgroundTransparency = 0.1,
            Icon = "136007050760089"
        },
        {
            Text = "Get Key 2",
            CopyContent = "https://link2.com",
            TextColor = "255,255,255",
            BackgroundColor = "60,60,80",
            BackgroundTransparency = 0.1,
            Icon = "136007050760089"
        },
        {
            Text = "Get Key 3",
            CopyContent = "https://link3.com",
            TextColor = "255,255,255",
            BackgroundColor = "60,60,80",
            BackgroundTransparency = 0.1,
            Icon = "136007050760089"
        },
        {
            Text = "Get Key 4",
            CopyContent = "https://link4.com",
            TextColor = "255,255,255",
            BackgroundColor = "60,60,80",
            BackgroundTransparency = 0.1,
            Icon = "136007050760089"
        }
    }
})
```
