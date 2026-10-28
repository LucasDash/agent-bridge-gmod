-- Fixed-eye offscreen capture, extracted from Mod Workbench's proven render lifecycle.
-- Rendering uses a separate target and does not change player view or controls.
if not CLIENT then error("Agent Bridge capture requires the client realm") end
AgentBridge = AgentBridge or {}
if AgentBridge.Capture then AgentBridge.Capture.Stop("reloaded") end
local C = {version = 1}
AgentBridge.Capture = C
local hookName = "AgentBridge.Capture"
local rendering = false
local width, height = 1280, 720

local function xyz(v) return {v.x, v.y, v.z} end
local function angles(a) return {a.p, a.y, a.r} end

local function persist(job)
    local data = util.TableToJSON(job.report, true)
    assert(isstring(data) and #data <= 65536, "Capture report exceeds its size limit")
    local path = job.path .. "/report.json"
    file.Write(path, data)
    assert(file.Read(path, "DATA") == data, "Capture report write failed")
end

function C.Status()
    local job = C.job
    return {available = true, version = C.version, active = job ~= nil,
        path = job and job.path or C.lastPath,
        captured = job and #job.report.frames or C.lastCount,
        requested = job and job.count or C.lastRequested,
        outcome = C.lastOutcome, final_save = C.lastSave and table.Copy(C.lastSave) or nil}
end

function C.Stop(reason)
    hook.Remove("PostRender", hookName)
    hook.Remove("Think", hookName)
    local job = C.job
    C.job = nil
    if not job then return {stopped = false, reason = "not_running"} end
    job.report.status = reason or "cancelled"
    job.report.finished_real_time = RealTime()
    local ok, err = pcall(persist, job)
    C.lastPath, C.lastCount, C.lastRequested = job.path, #job.report.frames, job.count
    C.lastOutcome = job.report.status
    C.lastSave = {saved = ok, report_path = job.path .. "/report.json",
        error = not ok and tostring(err):sub(1, 512) or nil}
    return {stopped = true, saved = ok, result = C.lastSave.report_path,
        error = C.lastSave.error, outcome = C.lastOutcome}
end

local function capture()
    local job = C.job
    if not job or rendering or RealTime() < job.next or gui.IsGameUIVisible() then return end
    rendering = true
    local pushed, in2d = false, false
    local ok, err = xpcall(function()
        render.PushRenderTarget(job.target)
        pushed = true
        render.Clear(0, 0, 0, 255, true, true)
        cam.Start2D()
        in2d = true
        render.RenderView({origin = job.origin, angles = job.angles, x = 0, y = 0,
            w = width, h = height, aspect = width / height, fov = job.fov, znear = 1,
            drawhud = false, drawviewmodel = false, drawmonitors = false,
            drawviewer = false, dopostprocess = false, bloomtone = false})
        cam.End2D()
        in2d = false
        local data = render.Capture({format = "png", x = 0, y = 0,
            w = width, h = height, alpha = false})
        assert(isstring(data) and #data > 0, "Renderer returned no image")
        render.PopRenderTarget()
        pushed = false
        local name = string.format("frame_%04d.png", #job.report.frames + 1)
        file.Write(job.path .. "/" .. name, data)
        assert(file.Size(job.path .. "/" .. name, "DATA") == #data, "Capture image write failed")
        job.report.frames[#job.report.frames + 1] = {file = name, bytes = #data,
            real_time = RealTime(), game_time = CurTime()}
        persist(job)
    end, debug.traceback)
    if in2d then
        local restored, issue = pcall(cam.End2D)
        if not restored then ok, err = false, issue end
    end
    if pushed then
        local restored, issue = pcall(render.PopRenderTarget)
        if not restored then ok, err = false, issue end
    end
    rendering = false
    if not ok then
        job.report.error = tostring(err):sub(1, 1024)
        C.Stop("error")
    elseif #job.report.frames >= job.count then
        C.Stop("complete")
    else
        job.next = RealTime() + 0.5
    end
end

function C.Start(args)
    args = args or {}
    assert(istable(args), "Arguments must be a table")
    assert(not C.job and not rendering, "Capture already active")
    assert(isstring(args.name) and #args.name <= 64 and args.name:match("^[%w_-]+$"),
        "Specify a unique safe capture name")
    local count = args.count == nil and 1 or args.count
    assert(isnumber(count) and count == math.floor(count) and count >= 1 and count <= 8,
        "Count must be an integer from 1 to 8")
    local p = LocalPlayer()
    assert(IsValid(p), "Local player unavailable")
    local path = "agent_bridge/captures/" .. args.name
    assert(not file.Exists(path, "DATA"), "Capture path already exists")
    local target = assert(GetRenderTarget("AgentBridgeCapture_v1_2048_1024", 2048, 1024),
        "Capture render target unavailable")
    local origin, a = p:EyePos(), p:EyeAngles()
    local job = {path = path, target = target, origin = Vector(origin.x, origin.y, origin.z),
        angles = Angle(a.p, a.y, a.r), fov = p:GetFOV(), count = count,
        next = RealTime(), deadline = RealTime() + 15}
    job.report = {schema = 1, tool = "AgentBridgeCapture", version = C.version,
        status = "running", map = game.GetMap(), started_real_time = RealTime(),
        started_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        width = width, height = height, format = "png", requested_frames = count,
        origin = xyz(job.origin), angles = angles(job.angles), fov = job.fov, frames = {}}
    file.CreateDir(path)
    persist(job)
    C.job = job
    C.lastSave, C.lastOutcome = nil, nil
    hook.Add("PostRender", hookName, capture)
    hook.Add("Think", hookName, function()
        if C.job and RealTime() >= C.job.deadline then C.Stop("timeout") end
    end)
    return {started = true, path = path, count = count, width = width, height = height}
end

concommand.Add("agent_bridge_capture_stop", function() C.Stop("cancelled") end)
