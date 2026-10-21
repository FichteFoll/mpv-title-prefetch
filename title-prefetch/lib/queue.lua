-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Runs title-resolving subprocesses with a concurrency limit and a timeout.

local msg = require("mp.msg")

---@class Job
---@field key string playlist entry filename; at most one job per key runs at a time
---@field runner Runner jobs with the same runner may share one subprocess

---@class Runner
---@field batch_size integer maximum number of jobs per subprocess, at least 1
---@field args fun(keys: string[]): string[] subprocess command line for these keys
---@field parse fun(keys: string[], stdout: string, result: SubprocessResult): RunOutcome

---Per-key outcomes of a subprocess that ran.
---A key missing from `keys` failed with the subprocess's own failure reason.
---@class RunOutcome
---@field retry boolean? retry every key instead of counting it, e.g. when the executable could not be started
---@field keys table<string, KeyOutcome>?

---@class KeyOutcome
---@field title string? nil when the key's run succeeded without a title
---@field detail string? failure detail; marks the key as failed and replaces the first stderr line in its reason

---@class SubprocessResult
---@field status integer exit code, or a negative value if the process did not exit normally
---@field stdout string?
---@field stderr string?
---@field error_string string "init" if the executable could not be started
---@field killed_by_us boolean

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

---@param result SubprocessResult
---@param detail? string replaces the first stderr line
---@return string
local function failure_reason(result, detail)
    if result.killed_by_us then
        return "aborted after the timeout"
    end
    local reason = "exit status " .. result.status
    if result.error_string ~= "" then
        reason = reason .. " (" .. result.error_string .. ")"
    end
    local line = detail or (result.stderr or ""):match("[^\r\n]+")
    if line then
        reason = reason .. ": " .. line
    end
    return reason
end

---Log the outcome of every key and return the titles, indexed like `keys`.
---@param keys string[]
---@param outcome RunOutcome
---@param result SubprocessResult
---@return table<integer, string> titles
local function log_outcomes(keys, outcome, result)
    ---@type table<integer, string>
    local titles = {}
    local outcomes = outcome.keys or {}
    for i, key in ipairs(keys) do
        local key_outcome = outcomes[key]
        if key_outcome and key_outcome.title then
            titles[i] = key_outcome.title
            msg.verbose("resolved " .. key .. ": " .. key_outcome.title)
        elseif key_outcome and not key_outcome.detail then
            msg.verbose("no title for " .. key)
        else
            msg.verbose("failed " .. key .. ": " .. failure_reason(result, key_outcome and key_outcome.detail))
        end
    end
    return titles
end

---@private
---@param jobs Job[] non-empty, all with the same runner
function Queue:start(jobs)
    local runner = jobs[1].runner
    ---@type string[]
    local keys = {}
    for i, job in ipairs(jobs) do
        keys[i] = job.key
    end

    self.running_count = self.running_count + 1
    for _, key in ipairs(keys) do
        self.running[key] = true
        msg.debug("starting " .. key .. " (" .. self.running_count .. "/" .. self.concurrency .. ")")
    end

    local timeout = self.timeout
    ---@type MpTimer?
    local timer
    local request = mp.command_native_async({
        name = "subprocess",
        args = runner.args(keys),
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }, function(success, result, err)
        -- The callback always runs asynchronously, so the timer is already set.
        if timer then
            timer:kill()
        end
        for _, key in ipairs(keys) do
            self.running[key] = nil
        end
        self.running_count = self.running_count - 1

        ---@type table<integer, string>
        local titles = {}
        local retry = false
        if not success or not result then
            for _, key in ipairs(keys) do
                msg.verbose("failed " .. key .. ": " .. tostring(err))
            end
        else
            local outcome = runner.parse(keys, result.stdout or "", result)
            retry = outcome.retry == true
            if not retry then
                titles = log_outcomes(keys, outcome, result)
            end
        end

        self:start_pending()
        for i, key in ipairs(keys) do
            self.on_done(key, titles[i], retry or nil)
        end
    end)
    if request then
        timer = mp.add_timeout(timeout, function()
            msg.warn("timed out after " .. tostring(timeout) .. " s: " .. table.concat(keys, ", "))
            mp.abort_async_command(request)
        end)
    end
end

---Take the first pending job and up to `batch_size - 1` further pending jobs
---with the same runner, in pending order.
---@private
---@return Job[]
function Queue:take_batch()
    local first = table.remove(self.pending, 1)
    local batch = {first}
    local i = 1
    while #batch < first.runner.batch_size and i <= #self.pending do
        if self.pending[i].runner == first.runner then
            batch[#batch + 1] = table.remove(self.pending, i)
        else
            i = i + 1
        end
    end
    return batch
end

---@private
function Queue:start_pending()
    while self.running_count < self.concurrency and #self.pending > 0 do
        self:start(self:take_batch())
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
