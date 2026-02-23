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
## Add Section
```luau
local Section = Window:AddSection({
    Name = "Section Name",
    Font = "SourceSansBold",
    Color = "255,255,255"
})
```
## Add Window Separator
### (In sections)
```luau
Window:AddSeparator()
```
## Add Section Separator
```luau
Section:AddSeparator()
```
## Add Head Text
```luau
Section:AddHeadText({
    Name = "Head Text",
    Font = "SourceSansBold",
    Color = "255,255,255",
    TextSize = 16,
    Lines = true,
    LineColor = "200,200,200"
})
```
## Add Toggle
```luau
Section:AddToggle({
    Name = "Toggle Name",
    Font = "SourceSans",
    Color = "255,255,255",
    TextSize = 14,
    Default = false,
    Bind = "F",
    Callback = function(state)
        print(state)
    end
})
```
## Add Button
```luau
Section:AddButton({
    Name = "Button Name",
    Font = "SourceSans",
    Color = "255,255,255",
    TextSize = 14,
    Bind = "K",
    Callback = function()
        print("Pressed")
    end
})
```
## Add Slider
```luau
Section:AddSlider({
    Name = "Slider Name",
    Font = "SourceSans",
    Color = "255,255,255",
    TextSize = 14,
    Min = 0,
    Max = 100,
    Default = 50,
    Increment = 1,
    Callback = function(value)
        print(value)
    end
})
```
## Add Dropdown
```luau
Section:AddDropdown({
    Name = "Dropdown Name",
    Font = "SourceSans",
    Color = "255,255,255",
    TextSize = 14,
    Options = {"Option 1", "Option 2", "Option 3"},
    Default = "Option 1",
    Multi = false,
    Callback = function(value)
        print(value)
    end
})
```
## Add TextBox
```luau
Section:AddTextBox({
    Name = "TextBox Name",
    Font = "SourceSans",
    Color = "255,255,255",
    TextSize = 14,
    Default = "...",
    Callback = function(text)
        print(text)
    end
})
```
## Add Label
```luau
Section:AddLabel({
    Text = "Label text",
    Font = "SourceSans",
    Color = "200,200,200",
    TextSize = 14,
    Lines = 2
})
```
## Add Color Picker
```luau
Section:AddColorPicker({
    Name = "Color Picker",
    Font = "SourceSansBold",
    Color = "255,255,255",
    TextSize = 14,
    Default = "255, 0, 0",
    Callback = function(rgb)
        print(rgb)
    end
})
```
## Add Notification
```luau
Section:AddNotification({
    Title = "Enabled",
    Description = "Feature activated",
    TitleColor = "255,255,255",
    TitleFont = "SourceSansBold",
    DescrColor = "200,200,200",
    DescrFont = "SourceSans",
    When = "On",
    Duration = 2
})
```
## Add Theme
```luau
Window:AddTheme("Custom Theme", {
    MainColor = "25,25,25",
    InnerColor = "35,35,35",
    AccentColor = "0,170,255",
    TextColor = "255,255,255",
    MainTransparency = 0,
    InnerTransparency = 0
})
```
