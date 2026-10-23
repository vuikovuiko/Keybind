--[[ 

This module is made by Vuiko (Vuiko_2)

Module documentation:
github.com/vuikovuiko/Keybind/

NON-AI-ZLIB License applied
License reference: github.com/vuikovuiko/Keybind/blob/main/LICENSE

--]]

----- Services -----

const ContextActionService = game:GetService(`ContextActionService`)
const GuiService = game:GetService(`GuiService`)
const HttpService = game:GetService(`HttpService`)
const UserInputService = game:GetService(`UserInputService`)

----- Types -----

export type connection = {
	Disconnect: (self: connection) -> (),
	_tiedSignal: any,
	_connectionID: string,
}

export type signal<T...> = {
	Connect: (self: signal<T...>, callback: (T...) -> ()) -> connection,
	Destroy: (self: signal<T...>) -> (),
	_fire: (self: signal<T...>, T...) -> (),
	_callbacks: { [string]: (T...) -> () },
}

type bindObjectInternal = {

	_tapEnabled: true?,
	_createButton: false?,
	_buttonPosition: UDim2?,

	_currentDevice: "keyboard" | "mobile" | "controller",
	_id: string,

	_keycodes: { Enum.KeyCode | Enum.UserInputType },
	_activeConnections: { [any]: RBXScriptConnection },
	_inputChanged: RBXScriptConnection,

	_propertyUpdated: signal<nil>,

	_bindConnections: (self: bindObject) -> (),
	_unbindConnection: (self: bindObject) -> (),
	_getScreenPosition: (self: bindObject) -> (),
}

export type bindObject = {

	ignoreProcessed: true?,
	ignoreGuiInset: true?,

	Activated: signal<Vector2>,
	Released: signal<Vector2>,
	DeviceChanged: signal<"keyboard" | "mobile" | "controller">,

	GetDevice: (self: bindObject) -> string,
	ToggleTouch: (self: bindObject, true?) -> (),
	CreateButton: (self: bindObject, false?) -> (),
	AddBinds: (self: bindObject, ...Enum.KeyCode | Enum.UserInputType) -> (),
	SetButtonPosition: (self: bindObject, position: UDim2) -> (),
	Destroy: (self: bindObject) -> (),
}

----- Variables -----

local objects = {}
local module = {}
local signal = {}
local connection = {}

----- Connections / Signals -----

-- for internal use only
function signal.New(): signal<any>
	local self = setmetatable({ _callbacks = {} }, { __index = signal })

	return self
end

function signal._fire(self: signal<any>, ...: any)
	for _, callback: () -> ...any? in self._callbacks do
		task.spawn(callback, ...)
	end
end

function signal.Connect(self: signal<any>, callback: (...any?) -> ()): connection
	local connectionID = HttpService:GenerateGUID(false)
	self._callbacks[connectionID] = callback

	-- creating connection

	local connection = setmetatable({}, { __index = connection })

	connection._connectionID = connectionID
	connection._tiedSignal = self

	return connection
end

function signal.Destroy(self: signal<any>)
	for connectionId in self._callbacks do
		self._callbacks[connectionId] = nil
	end
end

-- Disconnects current connection, function attached will no longer be triggered
function connection.Disconnect(self: connection)
	self._tiedSignal._callbacks[self._connectionID] = nil
end

----- Utils -----

function module._getScreenPosition(self: bindObject & bindObjectInternal, input: InputObject): Vector2
	local inset = Vector2.zero
	if self.ignoreGuiInset then
		inset = GuiService:GetGuiInset()
	end

	if self._currentDevice == `mobile` then
		return Vector2.new(input.Position.X, input.Position.Y) - inset
	end
	return UserInputService:GetMouseLocation() - inset
end

----- Functions -----

-- Destroys bindObject, and doing cleanup relative to object
function module.Destroy(self: bindObject & bindObjectInternal)
	-- signals cleanup
	self._propertyUpdated:Destroy()
	self.Activated:Destroy()
	self.Released:Destroy()
	self.DeviceChanged:Destroy()

	-- disconnecting any input connections
	self:_unbindConnection()
	self._inputChanged:Disconnect()

	-- keybind cleanup
	for key in self._keycodes do
		self._keycodes[key] = nil
	end

	-- destroying object
	const id = self._id
	table.clear(self)

	objects[id] = nil
end

function module.ToggleTouch(self: bindObject & bindObjectInternal, toggle: boolean?)
	self._tapEnabled = toggle or true
	self._propertyUpdated:_fire()
end

function module.AddBinds(self: bindObject & bindObjectInternal, ...: Enum.KeyCode | Enum.UserInputType)
	for _, keyCode in { ... } do
		table.insert(self._keycodes, keyCode)
	end
end

function module.GetDevice(self: bindObject & bindObjectInternal): string
	return self._currentDevice or `undefined`
end

function module.SetButtonPosition(self: bindObject & bindObjectInternal, position: UDim2)
	if position then
		self._buttonPosition = position
		self._propertyUpdated:_fire()
	else
		warn(`Expected UDim2, got {typeof(position)}, using defaults.`)
	end
end

function module.CreateButton(self: bindObject & bindObjectInternal, create: false?)
	self._createButton = create or false
	self._propertyUpdated:_fire()
end

function module._bindConnections(self: bindObject & bindObjectInternal)
	-- Input handling

	self._activeConnections.InputBegan = UserInputService.InputBegan:Connect(
		function(inputObject: InputObject, processed: boolean)
			if self.ignoreProcessed and processed then
				return
			end

			const screenPos = self:_getScreenPosition(inputObject)

			-- checking if it is phone
			if self._tapEnabled and inputObject.UserInputType == Enum.UserInputType.Touch then
				self.Activated:_fire(screenPos)
				return
			end

			-- looping trough all keycodes
			for _, keycode in self._keycodes do
				-- Ignoring processed if enabled
				if keycode == inputObject.KeyCode then
					self.Activated:_fire(screenPos)
					return
				end

				if keycode == inputObject.UserInputType then
					self.Activated:_fire(screenPos)
					return
				end
			end
		end
	)

	-- Input end handling

	self._activeConnections.InputEnded = UserInputService.InputEnded:Connect(
		function(inputObject: InputObject, processed: boolean)
			if self.ignoreProcessed and processed then
				return
			end

			const screenPos = self:_getScreenPosition(inputObject)

			-- checking if it is phone
			if self._tapEnabled and inputObject.UserInputType == Enum.UserInputType.Touch then
				self.Released:_fire(screenPos)
				return
			end

			-- looping trough all keycodes
			for _, keycode in self._keycodes do
				-- Ignoring processed if enabled
				if keycode == inputObject.KeyCode then
					self.Released:_fire(screenPos)
					return
				end

				if keycode == inputObject.UserInputType then
					self.Released:_fire(screenPos)
					return
				end
			end
		end
	)

	-- binding phone button input
	if self._createButton then
		ContextActionService:BindAction(
			self._id,
			function(_: string, inputState: Enum.UserInputState, inputObject: InputObject)
				if inputState == Enum.UserInputState.Begin then
					self.Activated:_fire(self:_getScreenPosition(inputObject))
					return
				end

				if inputState == Enum.UserInputState.End then
					self.Released:_fire(self:_getScreenPosition(inputObject))
					return
				end
			end,
			self._createButton
		)
		if self._buttonPosition then
			ContextActionService:SetPosition(self._id, self._buttonPosition)
		end
	end
end

function module._unbindConnection(self: bindObject & bindObjectInternal)
	for _, connection in self._activeConnections do
		connection:Disconnect()
	end

	ContextActionService:UnbindAction(self._id)
	table.clear(self._activeConnections)
end

function module._fireOnInput(self: bindObject & bindObjectInternal)
	local function rebind()
		-- Disconnecting old connections
		self:_unbindConnection()

		-- Binding new functions
		self:_bindConnections()
	end

	-- Rebind if device changed
	self.DeviceChanged:Connect(rebind)

	-- Rebind if property changed / added (Touch enabled / KeybindAdded)
	self._propertyUpdated:Connect(rebind)

	-- Monitoring device change
	self._inputChanged = UserInputService.InputChanged:Connect(function(inputObject: InputObject, processed: boolean)
		if
			(
				inputObject.UserInputType == Enum.UserInputType.Keyboard
				or inputObject.UserInputType == Enum.UserInputType.MouseMovement
			) and self._currentDevice ~= `keyboard`
		then
			self._currentDevice = `keyboard`
			self.DeviceChanged:_fire(self._currentDevice)
		elseif inputObject.UserInputType == Enum.UserInputType.Gamepad1 and self._currentDevice ~= `controller` then
			self._currentDevice = `controller`
			self.DeviceChanged:_fire(self._currentDevice)
		elseif inputObject.UserInputType == Enum.UserInputType.Touch and self._currentDevice ~= `mobile` then
			self._currentDevice = `mobile`
			self.DeviceChanged:_fire(self._currentDevice)
		end
	end)
end

return function(): bindObject
	local self = setmetatable({}, { __index = module })

	-- signals
	self.Released = signal.New() :: signal<Vector2>
	self.Activated = signal.New() :: signal<Vector2>
	self.DeviceChanged = signal.New() :: signal<"keyboard" | "mobile" | "controller">
	self._propertyUpdated = signal.New() :: signal<any>

	-- variable properties
	self.ignoreProcessed = true
	self.ignoreGuiInset = true
	self._createButton = false
	self._buttonPosition = nil
	self._tapEnabled = false

	self._currentDevice = `keyboard`

	self._id = HttpService:GenerateGUID(false)
	self._keycodes = {}
	self._activeConnections = {}

	-- one time binding all connections
	self:_bindConnections()

	-- activating input listening
	self:_fireOnInput()

	objects[self._id] = self

	return self
end
