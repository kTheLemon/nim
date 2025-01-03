-- LOVE2D Animation / Lerping library by k_lemon. Please read through this comment to make sure you understand how this library works BTS.
-- Call the "nim.injectUpdateFunc" function in order for animations to update.
local nim = {}

-- -- Lerping
nim.Easings = {}

---@alias easing_func fun(start_val:number, end_val:number, t:number, param:table?):number
---@alias easing_func_set table<string, easing_func>
---@alias input_func fun(t:number, param:table?):number

---@param t number
function nim.Easings.checkTime(t)
    return math.max(0, math.min(1, t))
end

---@param func input_func
---@return easing_func
function nim.Easings.new(func)
    return function(start_val, end_val, t, param)
        return nim.Easings.checkTime(func(t, param)) * (end_val - start_val) + start_val
    end
end

---@param func input_func
---@return easing_func_set
function nim.Easings.newRange(func)
    return {
        ---@type easing_func
        ["in"] = function(start_val, end_val, t, param)
            nim.Easings.checkTime(t)
            return func(t, param) * (end_val - start_val) + start_val
        end,

        ---@type easing_func
        ["out"] = function(start_val, end_val, t, param)
            nim.Easings.checkTime(t)
            return (1 - func(1 - t, param)) * (end_val - start_val) + start_val
        end,

        ---@type easing_func
        ["inout"] = function(start_val, end_val, t, param)
            nim.Easings.checkTime(t)
            if t <= 0.5 then
                return func(t, param) * (end_val - start_val) + start_val
            elseif t > 0.5 then
                return (1 - func(1 - t, param)) * (end_val - start_val) + start_val
            end
            return 0
        end,

        ---@type easing_func
        ["outin"] = function(start_val, end_val, t, param)
            nim.Easings.checkTime(t)
            if t <= 0.5 then
                return (1 - func(1 - t, param)) * (end_val - start_val) + start_val
            elseif t > 0.5 then
                return func(t, param) * (end_val - start_val) + start_val
            end
            return 0
        end,
    }
end

nim.halfpi = math.pi/2

nim.Easings.null = nim.Easings.new(
    function()
        return 0
    end
)

nim.Easings.instant = nim.Easings.new(
    function()
        return 1
    end
)

nim.Easings.linear = nim.Easings.new(
    function(t)
        return t
    end
)

nim.Easings.sine = nim.Easings.newRange(
    function(t)
        return 1 - (math.sin((1 - t) * nim.halfpi))
    end
)

-- Param[1] is what exponent to raise x by
nim.Easings.expo = nim.Easings.newRange(
    function(t, param)
        return t ^ param[1]
    end
)

-- A keyframe is a small fragment of an animation. Once it is completed, the animation will move on to the next keyframe (if there is one).
---@class KeyFrame
---@field func easing_func
---@field length number -- in seconds
---@field start_val number
---@field end_val number
---@field param table?
---@field val number
---@field time number
nim.KeyFrame = {}
nim.KeyFrame.__index = nim.KeyFrame

---@param func easing_func
---@param length number -- in seconds
---@param start_val number
---@param end_val number
---@param param table?
---@return KeyFrame
function nim.KeyFrame:new(func, length, start_val, end_val, param)
    return setmetatable({func = func, length = length, start_val = start_val or 0, end_val = end_val or 1, param = param or nil, val = start_val or 0, time = 0}, self)
end

---@param new_val number
function nim.KeyFrame:set_Val(new_val)
    self.val = new_val
end

---@return number
function nim.KeyFrame:get_Val()
    return self.val
end

---@param new_time number
function nim.KeyFrame:set_Time(new_time)
    nim.Easings.checkTime(new_time)
    self.time = new_time
end

---@param dt number
function nim.KeyFrame:update(dt)
    if self.time >= 1 then
        self:set_Val(self.func(self.start_val, self.end_val, self.time, self.param))
        return true
    end
    self:set_Time(self.time + dt/self.length)
    self:set_Val(self.func(self.start_val, self.end_val, self.time, self.param))
    return false
end

---@return KeyFrame
function nim.KeyFrame:copy()
    return nim.KeyFrame:new(self.func, self.length, self.start_val, self.end_val, self.param)
end

---@return KeyFrame
function nim.KeyFrame:pause(length, val)
    return nim.KeyFrame:new(nim.Easings.null, length, val, val)
end

-- An animation is a set of keyframes. These keyframes will be applied to whatever value is put in.
---@class Animation
---@field keyFrames table<number, KeyFrame>
---@field shouldLoop boolean
---@field curIdx number
---@field isPaused boolean
---@field shouldDeleteSelf boolean -- this field decides whether or not the animation should automatically delete itself from the queue once it's finished, on by default.
nim.Animation = {}
nim.Animation.__index = nim.Animation

---@param keyFrames table<number, KeyFrame>
---@param shouldLoop boolean?
---@param isPaused boolean?
---@param shouldDeleteSelf boolean? -- this parameter decides whether or not the animation should automatically delete itself from the queue once it's finished, off by default.
---@return Animation
function nim.Animation:new(keyFrames, shouldLoop, isPaused, shouldDeleteSelf)
    return setmetatable({keyFrames = keyFrames, shouldLoop = shouldLoop or false, curIdx = 1, isPaused = isPaused or false, shouldDeleteSelf = shouldDeleteSelf or false}, self)
end

---@return Animation
function nim.Animation:copy()
    local keyFrames = {}
    for i = 1, #self.keyFrames do
        keyFrames[i] = self.keyFrames[i]:copy()
    end
    return nim.Animation:new(keyFrames, self.shouldLoop)
end

---@return number
function nim.Animation:get_Val()
    return self.keyFrames[self.curIdx]:get_Val()
end

function nim.Animation:pause()
    self.isPaused = true
end

function nim.Animation:resume()
    self.isPaused = false
end

---@param dt number
---@return boolean
function nim.Animation:update(dt)
    local keyFrame_amnt = #self.keyFrames
    local cur_keyframe
    if not self.isPaused then
        cur_keyframe = self.keyFrames[self.curIdx]
        if cur_keyframe:update(dt) then
            cur_keyframe:set_Time(0)
            cur_keyframe:update(0)
            if self.shouldLoop == true then
                self.curIdx = (self.curIdx % keyFrame_amnt) + 1
            else
                self.curIdx = self.curIdx + 1
            end
        end
        if (self.curIdx > keyFrame_amnt) and (not self.shouldLoop) then
            self:pause()
            self.curIdx = keyFrame_amnt
            self.keyFrames[keyFrame_amnt]:set_Time(1)
            self.keyFrames[keyFrame_amnt]:update(0)
            return true
        end
    end
    return false
end

-- Animation queue, automatically loops through and updates every animation each update.
nim.Animation_Queue = {}
nim.id_Lookup = {}
nim.ascii_set = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ,?;.:+-*/!\\"\'|_'

---@param length number?
---@return string
function nim.randomID(length)
    local s = ''
    local rand_idx
    for _ = 1, length or 20 do
        rand_idx = love.math.random(1, #nim.ascii_set)
        s = s .. nim.ascii_set:sub(rand_idx, rand_idx)
    end
    return s
end

-- Runs an animation. The ID is used to access the animation's current value using nim.grabAnimationValue(id)
---@param id string
---@param start_val number?
function nim.Animation:run(id, start_val)
    nim.Animation_Queue[id] = {animation = self:copy(), start_val = start_val or 0}
    nim.id_Lookup[#nim.id_Lookup+1] = id
end

---@param id string|integer -- Only an integer if is_idx is set to true
---@param is_idx boolean? -- False by default, if you use the Index inside the ID lookup table instead of the ID itself, this should be set to true.
function nim.removeAnimation(id, is_idx)
    if not is_idx then
        nim.Animation_Queue[id] = nil
        for i = 1, #nim.id_Lookup do
            if nim.id_Lookup[i] == id then
                table.remove(nim.id_Lookup[i])
            end
        end
    elseif type(id) == "number" then
        local lookup_id = nim.id_Lookup[id]
        nim.Animation_Queue[lookup_id] = nil
        table.remove(nim.id_Lookup, id)
    end
end

function nim.grabAnimation(id)
    if nim.checkAnimation(id) then
        return nim.Animation_Queue[id].animation
    end
    error("Unable to index the Animation.\n Try setting the 'shouldDeleteSelf' parameter to false.")
end

function nim.checkAnimation(id)
    if nim.Animation_Queue[id] then
        return true
    end
    return false
end

---@param id string
---@return number?
function nim.grabAnimationValue(id)
    return nim.grabAnimation(id):get_Val() + nim.Animation_Queue[id].start_val
end

function nim.pauseAnimation(id)
    nim.grabAnimation(id):pause()
end

function nim.resumeAnimation(id)
    nim.grabAnimation(id):resume()
end

---@param dt number
function nim.updateAnimations(dt)
    local del_queue = {}
    local cur_id
    local cur_anim
    for i = 1, #nim.id_Lookup do
        cur_id = nim.id_Lookup[i]
        cur_anim = nim.Animation_Queue[cur_id].animation

        if cur_anim:update(dt) then
            if cur_anim.shouldDeleteSelf == true then
                del_queue[#del_queue+1] = i
            end
        end
    end
    for i = 1, #del_queue do
        nim.removeAnimation(i, true)
    end
end

---@param in_load boolean -- whether the injection should happen in love.load or not
function nim.injectUpdateFunc(in_load)
    if in_load then
        local prevload = love.load or function() end
        function love.load()
            local prevupdate = love.update or function() end
            function love.update(dt)
                nim.updateAnimations(dt)
                prevupdate(dt)
            end
            prevload()
        end
    else
        local prevupdate = love.update or function() end
        function love.update(dt)
            nim.updateAnimations(dt)
            prevupdate(dt)
        end
    end
end

return nim