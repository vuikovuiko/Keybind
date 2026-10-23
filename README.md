# Keybind

Luau module for cleaner code and easier input bindings

## API Reference with documentation:

### Creating object
As it is a object based module, you need to create bind object
```Luau
local bindObject = Keybind()
```

### Object properties
It has couple of properties available

ignoreProcessed property decides whether or not to ignore processed input (Input taken by core systems) :
```Luau
bindObject.ignoreProcessed = true -- Default is true
```
ignoreGuiInset property signifies ignorance of core GUI inset, and return screen position with subtracted inset :
```Luau
bindObject.ignoreGuiInset = true -- Default is true
```

### Signals and events

Object has three signals

Activated signal triggers when input begins on one of the Keycodes / UserInputTypes set, and returns position of interaction on screen (Vector2):

```Luau
bindObject.Activated:Connect(function( screenPosition : Vector2)
      print(`Button has been activated! The position is: { screenPosition }`)
end)
```

Released signal fires when the button for one of Keycodes or UserInputTypes gets released, returns position of interaction on screen (Vector2):
```Luau
bindObject.Released:Connect(function( screenPosition : Vector2)
      print(`Button has been released. The position is: { screenPosition }`)
end)
```

DeviceChanged fires when player changes input method, to for example Keyboard -> Controller:
```Luau
bindObject.DeviceChanged:Connect(function( deviceName : "keyboard" | "mobile" | "controller")
      print(`Device has been changed, current device name is: { deviceName }`)
end)
```
Each signal returns connection, which can be disconnected any time:
```Luau
local activatedConnection = bindObject.Activated:Connect(function( screenPosition : Vector2)
      print(`Button has been activated! The position is: { screenPosition }`)
end)

-- Disconnects after 5 seconds
task.wait(5)

-- Disconnecting
activatedConnection:Disconnect()
```

### Methods

Keybind object has 6 public methods

GetDevice function returns current device from which input is present:
```Luau
local currentDevice: "keyboard" | "mobile" | "controller" = bindObject:GetDevice()
```

ToggleTouch method enables touch input for screen touch devices, if no arguments is passed then default equals to true:
```Luau
bindObject:ToggleTouch( false ) -- Disables screen touch input
bindObject:ToggleTouch( true ) -- Enables screen touch input
```

CreateButton method decides if button for mobile devices will be created (ContextActionService button), if no arguments is passed then default equals to false:
```Luau
bindObject:CreateButton( false ) -- Disables button creation + Removes button if there is
bindObject:CreateButton( true ) -- Enables button creation + Creates button if there isn't
```

SetButtonPosition method sets position for button created by :CreateButton() within ContextButtonFrame, accepts one parameter with type of UDim2:
```Luau
bindObject:SetButtonPosition(UDim2.fromScale(0.5, 0.5)) -- Sets button position to 0.5, 0.5 within ContextButtonFrame boundaries
```

AddBinds function adds KeyCodes and UserInputTypes by which .Activated / .Released signals will be triggered, accepts tuple of KeyCode or UserInputType values:
```Luau
bindObject:AddBinds(Enum.UserInputType.MouseButton1, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
```

Destroy method cleans up all connections, tables, signals, Methods, properties and object itself:
```Luau
bindObject:Destroy()

local nextValue = next(bindObject)
print(`Next bindObject value is {nextValue}`)

-->>> Next bindObject value is nil
```










