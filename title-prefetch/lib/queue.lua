-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Runs title-resolving subprocesses with a concurrency limit and a timeout.

---@class Job
---@field key string playlist entry filename; at most one job per key runs at a time
---@field args string[] subprocess command line
---@field parse fun(stdout: string): string? extracts the title from the output

---@alias OnDone fun(key: string, title: string?)

---@class QueueArgs
---@field concurrency integer
---@field timeout number seconds
---@field on_done OnDone

---@class Queue
---@field private concurrency integer
---@field private timeout number
---@field private on_done OnDone
---@field private pending Job[]
---@field private running table<string, true>
---@field private running_count integer
local Queue = {}
Queue.__index = Queue

local queue = {}

---@param args QueueArgs
---@return Queue
function queue.new(args)
    return setmetatable({
        concurrency = args.concurrency,
        timeout = args.timeout,
        on_done = args.on_done,
        pending = {},
        running = {},
        running_count = 0,
    }, Queue)
end

---@param job Job
---@param success boolean
---@param result? table subprocess result
---@return string? title
local function parse_result(job, success, result)
    if not success or not result or result.status ~= 0 or result.killed_by_us then
        return nil
    end
    return job.parse(result.stdout or "")
end

---@private
---@param job Job
function Queue:start(job)
    self.running[job.key] = true
    self.running_count = self.running_count + 1

    ---@type MpTimer?
    local timer
    local request = mp.command_native_async({
        name = "subprocess",
        args = job.args,
        playback_only = false,
        capture_stdout = true,
    }, function(success, result)
        -- The callback always runs asynchronously, so the timer is already set.
        if timer then
            timer:kill()
        end
        self.running[job.key] = nil
        self.running_count = self.running_count - 1
        local title = parse_result(job, success, result)
        self:start_pending()
        self.on_done(job.key, title)
    end)
    if request then
        timer = mp.add_timeout(self.timeout, function()
            mp.abort_async_command(request)
        end)
    end
end

---@private
function Queue:start_pending()
    while self.running_count < self.concurrency and #self.pending > 0 do
        self:start(table.remove(self.pending, 1))
    end
end

---Replace all not-yet-started jobs with `jobs`, skipping those whose key is running.
---@param jobs Job[]
function Queue:set_wanted(jobs)
    ---@type Job[]
    local pending = {}
    for _, job in ipairs(jobs) do
        if not self.running[job.key] then
            pending[#pending + 1] = job
        end
    end
    self.pending = pending
    self:start_pending()
end

---@param concurrency integer
---@param timeout number seconds; applies to jobs started from now on
function Queue:set_limits(concurrency, timeout)
    self.concurrency = concurrency
    self.timeout = timeout
    self:start_pending()
end

---@param key string
---@return boolean
function Queue:is_running(key)
    return self.running[key] ~= nil
end

---@return boolean
function Queue:busy()
    return self.running_count > 0 or #self.pending > 0
end

return queue
