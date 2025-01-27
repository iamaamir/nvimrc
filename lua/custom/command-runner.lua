local M = {}
local config_file = vim.fn.stdpath 'data' .. '/command_runner.json'

-- Pre-configured commands
M.commands = {
  { name = 'Run Python', command = 'python' },
  { name = 'Run Node', command = 'node' },
  { name = 'Lint with ESLint', command = 'npx eslint' },
  { name = 'Format with Prettier', command = 'npx prettier --write' },
}

-- Store the last executed command
M.last_command = nil

-- Load commands from config file
local function load_commands()
  local file = io.open(config_file, 'r')
  if file then
    local content = file:read '*a'
    file:close()
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and type(data) == 'table' then
      M.commands = data
    end
  end
end

-- Save commands to config file
local function save_commands()
  local file = io.open(config_file, 'w')
  if file then
    file:write(vim.fn.json_encode(M.commands))
    file:close()
  end
end

-- Show the list of commands and execute the selected one
function M.run_command()
  local current_file = vim.fn.expand '%:p' -- Get the full path of the current file

  -- Ensure the current file exists
  if current_file == '' then
    vim.notify('No file is currently open!', vim.log.levels.ERROR)
    return
  end

  -- Prepare the list of command names for selection
  local command_names = {}
  for _, cmd in ipairs(M.commands) do
    table.insert(command_names, cmd.name)
  end
  table.insert(command_names, ' Add New Command')
  table.insert(command_names, ' Delete Command')

  -- Display a selection menu for the commands
  vim.ui.select(command_names, { prompt = 'Select a command to run:' }, function(choice)
    if not choice then
      return -- User canceled the selection
    end

    if choice == 'Add New Command' then
      M.add_command()
      return
    elseif choice == 'Delete Command' then
      M.delete_command()
      return
    end

    -- Find the selected command
    for _, cmd in ipairs(M.commands) do
      if cmd.name == choice then
        local full_command = cmd.command .. ' ' .. current_file
        M.last_command = full_command -- Store the last executed command

        -- Register the last command in register q
        vim.fn.setreg('q', M.last_command)

        -- Open a new terminal and run the command
        vim.cmd('10 split | terminal ' .. full_command)
        return
      end
    end
  end)
end

-- Re-run the last executed command
function M.rerun_last_command()
  if not M.last_command then
    vim.notify('No command has been executed yet!', vim.log.levels.ERROR)
    return
  end

  -- Register the last command in register q
  vim.fn.setreg('q', M.last_command)

  -- Open a new terminal and re-run the last command
  vim.cmd('split | terminal ' .. M.last_command)
end

-- Add a new command to the list
function M.add_command()
  vim.ui.input({ prompt = 'Enter command name:' }, function(name)
    if not name or name == '' then
      vim.notify('Command name cannot be empty!', vim.log.levels.ERROR)
      return
    end

    vim.ui.input({ prompt = 'Enter command (e.g., git add):' }, function(command)
      if not command or command == '' then
        vim.notify('Command cannot be empty!', vim.log.levels.ERROR)
        return
      end

      table.insert(M.commands, { name = name, command = command })
      save_commands()
      vim.notify('Command added successfully!', vim.log.levels.INFO)
    end)
  end)
end

-- Delete an existing command from the list
function M.delete_command()
  local command_names = {}
  for _, cmd in ipairs(M.commands) do
    table.insert(command_names, cmd.name)
  end

  vim.ui.select(command_names, { prompt = 'Select a command to delete:' }, function(choice)
    if not choice then
      return -- User canceled the selection
    end

    for i, cmd in ipairs(M.commands) do
      if cmd.name == choice then
        table.remove(M.commands, i)
        save_commands()
        vim.notify('Command deleted successfully!', vim.log.levels.INFO)
        return
      end
    end
  end)
end

-- Setup function to load commands on startup
function M.setup()
  load_commands()
  vim.keymap.set('n', '<leader>rc', M.run_command, { desc = 'Show a list of commands and run the selected one on the current file' })
  vim.keymap.set('n', '<leader>rr', M.rerun_last_command, { desc = 'Re-run the last executed command' })
end

return M
