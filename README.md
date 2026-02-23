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
