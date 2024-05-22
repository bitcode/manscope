local M = {}

M.LogLevel = {DEBUG = 1, INFO = 2, ERROR = 3}
M.currentLogLevel = M.LogLevel.DEBUG

local logLevelNames = {
    [M.LogLevel.DEBUG] = "DEBUG",
    [M.LogLevel.INFO] = "INFO",
    [M.LogLevel.ERROR] = "ERROR",
}

function M.log_to_file(msg, level)
    level = level or M.LogLevel.INFO
    if level < M.currentLogLevel then return end
    local log_file_path = vim.fn.stdpath('cache') .. '/manscope.log'
    local date = os.date('%Y-%m-%d %H:%M:%S')
    local final_message = string.format("[%s] [%s] %s\n", logLevelNames[level], date, msg)

    local file, err = io.open(log_file_path, 'a')
    if not file then
        vim.notify("Failed to open log file: " .. err, vim.log.levels.ERROR)
        return
    end

    local success, write_err = pcall(file.write, file, final_message)
    if not success then
        vim.notify("Failed to write to log file: " .. write_err, vim.log.levels.ERROR)
    end

    local close_success, close_err = pcall(file.close, file)
    if not close_success then
        vim.notify("Failed to close log file: " .. close_err, vim.log.levels.ERROR)
    end
end
