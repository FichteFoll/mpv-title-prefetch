-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Runs title-resolving subprocesses with a concurrency limit and a timeout.

local msg = require("mp.msg")

---@class Job
---@field key string playlist entry filename; at most one job per key runs at a time
---@field args string[] subprocess command line
---@field parse JobParse

---@class SubprocessResult
---@field status integer exit code, or a negative value if the process did not exit normally
---@field stdout string?
---@field stderr string?
---@field error_string string "init" if the executable could not be started
---@field killed_by_us boolean

---Extracts the title from the output.
---Returns `nil, true` when the job should be retried instead of counting as failed.
---@alias JobParse fun(stdout: string, result: SubprocessResult): title: string?, retry: boolean?

---Builds the jobs of one resolver for one scheduling pass.
---@alias JobFactory fun(filename: string): Job? nil when the resolver cannot run now

---`title` is nil when the job failed, and `retry` is true when it should be retried.
---@alias OnDone fun(key: string, title: string?, retry: boolean?)

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

---`parse` sees every completed result, so that it can request a retry,
---but its title is only used when the subprocess succeeded.
---@param job Job
---@param success boolean
---@param result? SubprocessResult
---@return string? title
---@return boolean? retry
local function parse_result(job, success, result)
    if not success or not result then
        return nil
    end
    local title, retry = job.parse(result.stdout or "", result)
    if retry then
        return nil, true
    end
    if result.status ~= 0 or result.killed_by_us then
        return nil
    end
    return title
end

---@param success boolean
---@param result? SubprocessResult
---@param err? string
---@return string
local function failure_reason(success, result, err)
    if not success or not result then
        return tostring(err)
    end
    if result.killed_by_us then
        return "aborted after the timeout"
    end
    local reason = "exit status " .. result.status
    if result.error_string ~= "" then
        reason = reason .. " (" .. result.error_string .. ")"
    end
    local line = (result.stderr or ""):match("[^\r\n]+")
    if line then
        reason = reason .. ": " .. line
    end
    return reason
end

---@param job Job
---@param success boolean
---@param result? SubprocessResult
---@param err? string
---@param title? string
local function log_result(job, success, result, err, title)
    if title then
        msg.verbose("resolved " .. job.key .. ": " .. title)
    elseif success and result and result.status == 0 and not result.killed_by_us then
        msg.verbose("no title for " .. job.key)
    else
        msg.verbose("failed " .. job.key .. ": " .. failure_reason(success, result, err))
    end
end

---@private
---@param job Job
function Queue:start(job)
    self.running[job.key] = true
    self.running_count = self.running_count + 1
    msg.debug("starting " .. job.key .. " (" .. self.running_count .. "/" .. self.concurrency .. ")")

    local timeout = self.timeout
    ---@type MpTimer?
    local timer
    local request = mp.command_native_async({
        name = "subprocess",
        args = job.args,
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }, function(success, result, err)
        -- The callback always runs asynchronously, so the timer is already set.
        if timer then
            timer:kill()
        end
        self.running[job.key] = nil
        self.running_count = self.running_count - 1
        local title, retry = parse_result(job, success, result)
        if not retry then
            log_result(job, success, result, err, title)
        end
        self:start_pending()
        self.on_done(job.key, title, retry)
    end)
    if request then
        timer = mp.add_timeout(timeout, function()
            msg.warn("timed out after " .. tostring(timeout) .. " s: " .. job.key)
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
    ---@type table<string, true>
    local wanted = {}
    ---@type Job[]
    local pending = {}
    for _, job in ipairs(jobs) do
        wanted[job.key] = true
        if not self.running[job.key] then
            pending[#pending + 1] = job
        end
    end
    local dropped = 0
    for _, job in ipairs(self.pending) do
        if not wanted[job.key] then
            dropped = dropped + 1
        end
    end
    if dropped > 0 then
        msg.debug("dropped " .. dropped .. " pending jobs")
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
