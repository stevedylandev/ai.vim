local M = {}

local config = require("_ai/config")

---@param cmd string
---@param args string[]
---@param on_stdout_chunk fun(chunk: string): nil
---@param on_complete fun(err: string?, output: string?): nil
local function exec (cmd, args, on_stdout_chunk, on_complete)
    local stdout = vim.loop.new_pipe()
    local function on_stdout_read (_, chunk)
        if chunk then
            vim.schedule(function ()
                on_stdout_chunk(chunk)
            end)
        end
    end

    local stderr = vim.loop.new_pipe()
    local stderr_chunks = {}
    local function on_stderr_read (_, chunk)
        if chunk then
            table.insert(stderr_chunks, chunk)
        end
    end

    local handle

    handle, error = vim.loop.spawn(cmd, {
        args = args,
        stdio = {nil, stdout, stderr},
    }, function (code)
        stdout:close()
        stderr:close()
        handle:close()

        vim.schedule(function ()
            if code ~= 0 then
                on_complete(vim.trim(table.concat(stderr_chunks, "")))
            else
                on_complete()
            end
        end)
    end)

    if not handle then
        on_complete(cmd .. " could not be started: " .. error)
    else
        stdout:read_start(on_stdout_read)
        stderr:read_start(on_stderr_read)
    end
end

local function request (body, on_data, on_complete)
    local api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key then
        on_complete("$ANTHROPIC_API_KEY environment variable must be set")
        return
    end

    local curl_args = {
        "--silent", "--show-error", "--no-buffer",
        "--max-time", config.timeout,
        "-L", "https://api.anthropic.com/v1/messages",
        "-H", "x-api-key: " .. api_key,
        "-H", "anthropic-version: 2023-06-01",
        "-X", "POST", "-H", "Content-Type: application/json",
        "-d", vim.json.encode(body),
    }

    local buffered_chunks = ""
    local function on_stdout_chunk (chunk)
        buffered_chunks = buffered_chunks .. chunk

        -- Extract complete event blocks from the buffered_chunks
        -- Claude streams in SSE format with event: and data: lines
        while true do
            local event_start = buffered_chunks:find("event: ")
            if not event_start then break end

            local data_start = buffered_chunks:find("data: ", event_start)
            if not data_start then break end

            local next_event = buffered_chunks:find("\n\n", data_start)
            if not next_event then break end

            local event_line = buffered_chunks:sub(event_start, data_start - 1)
            local data_line = buffered_chunks:sub(data_start, next_event - 1)
            buffered_chunks = buffered_chunks:sub(next_event + 2)

            -- Extract and trim event type
            local event_type = event_line:match("event:%s*(.-)%s*\n")
            -- Extract and trim JSON data
            local json_str = data_line:match("data:%s*(.-)%s*$")

            if event_type and json_str then
                local success, json = pcall(vim.json.decode, json_str)
                if success then
                    if json.error then
                        on_complete(json.error.message)
                        return
                    elseif event_type == "content_block_delta" then
                        on_data(json)
                    elseif event_type == "error" then
                        on_complete(json.error and json.error.message or "Unknown error")
                        return
                    end
                end
            end
        end
    end

    exec("curl", curl_args, on_stdout_chunk, on_complete)
end

---@param prompt string
---@param suffix string?
---@param on_data fun(data: unknown): nil
---@param on_complete fun(err: string?): nil
function M.completions (prompt, suffix, on_data, on_complete)
    local user_message
    if suffix and suffix ~= "" then
        -- Fill-in-the-middle completion
        user_message = prompt .. "<FILL>" .. suffix
    else
        user_message = prompt
    end

    local body = {
        model = config.model,
        max_tokens = 2048,
        temperature = config.temperature,
        stream = true,
        messages = {
            {
                role = "user",
                content = user_message
            }
        }
    }

    request(body, on_data, on_complete)
end

---@param input string
---@param instruction string
---@param on_data fun(data: unknown): nil
---@param on_complete fun(err: string?): nil
function M.edits (input, instruction, on_data, on_complete)
    local user_message = instruction .. "\n\n" .. input .. "\n\nOnly output the result with no markdown formatting, explanations, or code fences. Return only the modified text exactly as it should replace the original."

    local body = {
        model = config.model,
        max_tokens = 2048,
        temperature = config.temperature,
        stream = true,
        messages = {
            {
                role = "user",
                content = user_message
            }
        }
    }

    request(body, on_data, on_complete)
end

return M
