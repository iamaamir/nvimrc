--[[
  Gitmoji Picker
  Browse and select gitmojis for commit messages
  API: https://gitmoji.dev/api/gitmojis
--]]

local utils = require 'custom.git-workflow.utils'

local M = {}

-- Cache for gitmojis (fetched from API)
local cached_gitmojis = nil

--- Insert text at specific position in buffer
---@param bufnr number Buffer number
---@param row number Row (0-indexed)
---@param col number Column (0-indexed)
---@param text string Text to insert
local function insert_at_position(bufnr, row, col, text)
  -- Use nvim_buf_set_text for reliable insertion at exact position
  vim.api.nvim_buf_set_text(bufnr, row, col, row, col, { text })
  -- Move cursor to end of inserted text
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(win, { row + 1, col + #text })
end

--- Fetch gitmojis from API
---@return table|nil Array of gitmojis or nil on error
---@return boolean|nil True if fetched from API, false if using cache, nil if failed
local function fetch_gitmojis()
  if cached_gitmojis then
    return cached_gitmojis, false -- Using cache
  end
  -- Try to fetch from API
  local curl_cmd = 'curl -s https://gitmoji.dev/api/gitmojis'
  local json_output = vim.fn.system(curl_cmd)
  if vim.v.shell_error ~= 0 or not json_output or json_output == '' then
    return nil, nil -- Failed to fetch
  end
  -- Parse JSON (using vim.json.decode which is available in Neovim 0.7+)
  local ok, data = pcall(vim.json.decode, json_output)
  if not ok or not data or not data.gitmojis then
    return nil, nil -- Failed to parse
  end
  cached_gitmojis = data.gitmojis
  return cached_gitmojis, true -- Successfully fetched from API
end

--- Fallback gitmojis (used if API fetch fails)
local fallback_gitmojis = {
  { emoji = '🎨', code = ':art:', description = 'Improve structure / format of the code.', name = 'art' },
  { emoji = '⚡️', code = ':zap:', description = 'Improve performance.', name = 'zap', semver = 'patch' },
  { emoji = '🔥', code = ':fire:', description = 'Remove code or files.', name = 'fire' },
  { emoji = '🐛', code = ':bug:', description = 'Fix a bug.', name = 'bug', semver = 'patch' },
  { emoji = '🚑️', code = ':ambulance:', description = 'Critical hotfix.', name = 'ambulance', semver = 'patch' },
  { emoji = '✨', code = ':sparkles:', description = 'Introduce new features.', name = 'sparkles', semver = 'minor' },
  { emoji = '📝', code = ':memo:', description = 'Add or update documentation.', name = 'memo' },
  { emoji = '🚀', code = ':rocket:', description = 'Deploy stuff.', name = 'rocket' },
  { emoji = '💄', code = ':lipstick:', description = 'Add or update the UI and style files.', name = 'lipstick', semver = 'patch' },
  { emoji = '🎉', code = ':tada:', description = 'Begin a project.', name = 'tada' },
  { emoji = '✅', code = ':white_check_mark:', description = 'Add, update, or pass tests.', name = 'white-check-mark' },
  { emoji = '🔒️', code = ':lock:', description = 'Fix security or privacy issues.', name = 'lock', semver = 'patch' },
  { emoji = '🔐', code = ':closed_lock_with_key:', description = 'Add or update secrets.', name = 'closed-lock-with-key' },
  { emoji = '🔖', code = ':bookmark:', description = 'Release / Version tags.', name = 'bookmark' },
  { emoji = '🚨', code = ':rotating_light:', description = 'Fix compiler / linter warnings.', name = 'rotating-light' },
  { emoji = '🚧', code = ':construction:', description = 'Work in progress.', name = 'construction' },
  { emoji = '💚', code = ':green_heart:', description = 'Fix CI Build.', name = 'green-heart' },
  { emoji = '⬇️', code = ':arrow_down:', description = 'Downgrade dependencies.', name = 'arrow-down', semver = 'patch' },
  { emoji = '⬆️', code = ':arrow_up:', description = 'Upgrade dependencies.', name = 'arrow-up', semver = 'patch' },
  { emoji = '📌', code = ':pushpin:', description = 'Pin dependencies to specific versions.', name = 'pushpin', semver = 'patch' },
  { emoji = '👷', code = ':construction_worker:', description = 'Add or update CI build system.', name = 'construction-worker' },
  {
    emoji = '📈',
    code = ':chart_with_upwards_trend:',
    description = 'Add or update analytics or track code.',
    name = 'chart-with-upwards-trend',
    semver = 'patch',
  },
  { emoji = '♻️', code = ':recycle:', description = 'Refactor code.', name = 'recycle' },
  { emoji = '➕', code = ':heavy_plus_sign:', description = 'Add a dependency.', name = 'heavy-plus-sign', semver = 'patch' },
  { emoji = '➖', code = ':heavy_minus_sign:', description = 'Remove a dependency.', name = 'heavy-minus-sign', semver = 'patch' },
  { emoji = '🔧', code = ':wrench:', description = 'Add or update configuration files.', name = 'wrench', semver = 'patch' },
  { emoji = '🔨', code = ':hammer:', description = 'Add or update development scripts.', name = 'hammer' },
  { emoji = '🌐', code = ':globe_with_meridians:', description = 'Internationalization and localization.', name = 'globe-with-meridians', semver = 'patch' },
  { emoji = '✏️', code = ':pencil2:', description = 'Fix typos.', name = 'pencil2', semver = 'patch' },
  { emoji = '💩', code = ':poop:', description = 'Write bad code that needs to be improved.', name = 'poop' },
  { emoji = '⏪️', code = ':rewind:', description = 'Revert changes.', name = 'rewind', semver = 'patch' },
  { emoji = '🔀', code = ':twisted_rightwards_arrows:', description = 'Merge branches.', name = 'twisted-rightwards-arrows' },
  { emoji = '📦️', code = ':package:', description = 'Add or update compiled files or packages.', name = 'package', semver = 'patch' },
  { emoji = '👽️', code = ':alien:', description = 'Update code due to external API changes.', name = 'alien', semver = 'patch' },
  { emoji = '🚚', code = ':truck:', description = 'Move or rename resources (e.g.: files, paths, routes).', name = 'truck' },
  { emoji = '📄', code = ':page_facing_up:', description = 'Add or update license.', name = 'page-facing-up' },
  { emoji = '💥', code = ':boom:', description = 'Introduce breaking changes.', name = 'boom', semver = 'major' },
  { emoji = '🍱', code = ':bento:', description = 'Add or update assets.', name = 'bento', semver = 'patch' },
  { emoji = '♿️', code = ':wheelchair:', description = 'Improve accessibility.', name = 'wheelchair', semver = 'patch' },
  { emoji = '💡', code = ':bulb:', description = 'Add or update comments in source code.', name = 'bulb' },
  { emoji = '🍻', code = ':beers:', description = 'Write code drunkenly.', name = 'beers' },
  { emoji = '💬', code = ':speech_balloon:', description = 'Add or update text and literals.', name = 'speech-balloon', semver = 'patch' },
  { emoji = '🗃️', code = ':card_file_box:', description = 'Perform database related changes.', name = 'card-file-box', semver = 'patch' },
  { emoji = '🔊', code = ':loud_sound:', description = 'Add or update logs.', name = 'loud-sound' },
  { emoji = '🔇', code = ':mute:', description = 'Remove logs.', name = 'mute' },
  { emoji = '👥', code = ':busts_in_silhouette:', description = 'Add or update contributor(s).', name = 'busts-in-silhouette' },
  { emoji = '🚸', code = ':children_crossing:', description = 'Improve user experience / usability.', name = 'children-crossing', semver = 'patch' },
  { emoji = '🏗️', code = ':building_construction:', description = 'Make architectural changes.', name = 'building-construction' },
  { emoji = '📱', code = ':iphone:', description = 'Work on responsive design.', name = 'iphone', semver = 'patch' },
  { emoji = '🤡', code = ':clown_face:', description = 'Mock things.', name = 'clown-face' },
  { emoji = '🥚', code = ':egg:', description = 'Add or update an easter egg.', name = 'egg', semver = 'patch' },
  { emoji = '🙈', code = ':see_no_evil:', description = 'Add or update a .gitignore file.', name = 'see-no-evil' },
  { emoji = '📸', code = ':camera_flash:', description = 'Add or update snapshots.', name = 'camera-flash' },
  { emoji = '⚗️', code = ':alembic:', description = 'Perform experiments.', name = 'alembic', semver = 'patch' },
  { emoji = '🔍️', code = ':mag:', description = 'Improve SEO.', name = 'mag', semver = 'patch' },
  { emoji = '🏷️', code = ':label:', description = 'Add or update types.', name = 'label', semver = 'patch' },
  { emoji = '🌱', code = ':seedling:', description = 'Add or update seed files.', name = 'seedling' },
  {
    emoji = '🚩',
    code = ':triangular_flag_on_post:',
    description = 'Add, update, or remove feature flags.',
    name = 'triangular-flag-on-post',
    semver = 'patch',
  },
  { emoji = '🥅', code = ':goal_net:', description = 'Catch errors.', name = 'goal-net', semver = 'patch' },
  { emoji = '💫', code = ':dizzy:', description = 'Add or update animations and transitions.', name = 'dizzy', semver = 'patch' },
  { emoji = '🗑️', code = ':wastebasket:', description = 'Deprecate code that needs to be cleaned up.', name = 'wastebasket', semver = 'patch' },
  {
    emoji = '🛂',
    code = ':passport_control:',
    description = 'Work on code related to authorization, roles and permissions.',
    name = 'passport-control',
    semver = 'patch',
  },
  { emoji = '🩹', code = ':adhesive_bandage:', description = 'Simple fix for a non-critical issue.', name = 'adhesive-bandage', semver = 'patch' },
  { emoji = '🧐', code = ':monocle_face:', description = 'Data exploration/inspection.', name = 'monocle-face' },
  { emoji = '⚰️', code = ':coffin:', description = 'Remove dead code.', name = 'coffin' },
  { emoji = '🧪', code = ':test_tube:', description = 'Add a failing test.', name = 'test-tube' },
  { emoji = '👔', code = ':necktie:', description = 'Add or update business logic.', name = 'necktie', semver = 'patch' },
  { emoji = '🩺', code = ':stethoscope:', description = 'Add or update healthcheck.', name = 'stethoscope' },
  { emoji = '🧱', code = ':bricks:', description = 'Infrastructure related changes.', name = 'bricks' },
  { emoji = '🧑‍💻', code = ':technologist:', description = 'Improve developer experience.', name = 'technologist' },
  { emoji = '💸', code = ':money_with_wings:', description = 'Add sponsorships or money related infrastructure.', name = 'money-with-wings' },
  { emoji = '🧵', code = ':thread:', description = 'Add or update code related to multithreading or concurrency.', name = 'thread' },
  { emoji = '🦺', code = ':safety_vest:', description = 'Add or update code related to validation.', name = 'safety-vest' },
  { emoji = '✈️', code = ':airplane:', description = 'Improve offline support.', name = 'airplane' },
  { emoji = '🦖', code = ':t-rex:', description = 'Code that adds backwards compatibility.', name = 't-rex' },
}

--- Create and show gitmoji picker
---@param opts? table Optional configuration
function M.picker(opts)
  opts = opts or {}
  local telescope = utils.load_telescope()
  local themes = require 'telescope.themes'
  -- Store the original buffer, window, and cursor position BEFORE opening picker
  local original_bufnr = vim.api.nvim_get_current_buf()
  local original_win = vim.api.nvim_get_current_win()
  local original_cursor = vim.api.nvim_win_get_cursor(original_win)
  local original_row = original_cursor[1] - 1 -- 0-indexed
  local original_col = original_cursor[2] -- 0-indexed
  -- Fetch gitmojis from API (with fallback)
  local gitmojis, fetch_status = fetch_gitmojis()
  if not gitmojis then
    -- Fall back to cached or fallback data
    gitmojis = cached_gitmojis or fallback_gitmojis
    if not cached_gitmojis then
      -- Only notify if we're using fallback (not cached)
      utils.notify_warn('Using fallback gitmojis (API unavailable). Total: ' .. #gitmojis)
    end
  elseif fetch_status == true then
    -- Successfully fetched from API
    utils.notify_success('Fetched latest gitmojis from API (' .. #gitmojis .. ' emojis)')
  end

  if not gitmojis or #gitmojis == 0 then
    utils.notify_error 'No gitmojis available'
    return
  end

  -- Merge custom gitmojis (add at the very top)
  local custom_gitmojis = opts.custom_gitmojis or {}
  if custom_gitmojis and #custom_gitmojis > 0 then
    -- Create a set of custom codes to track and remove duplicates
    local custom_codes = {}
    for _, custom in ipairs(custom_gitmojis) do
      if custom.code then
        custom_codes[custom.code] = true
      end
    end

    -- Remove duplicates from base list (gitmojis that match custom codes)
    local deduplicated_gitmojis = {}
    for _, gitmoji in ipairs(gitmojis) do
      if not gitmoji.code or not custom_codes[gitmoji.code] then
        table.insert(deduplicated_gitmojis, gitmoji)
      end
    end
    gitmojis = deduplicated_gitmojis

    -- Prepend custom gitmojis to the list (so they appear first)
    for i = #custom_gitmojis, 1, -1 do
      table.insert(gitmojis, 1, custom_gitmojis[i])
    end
    utils.notify_success('Added ' .. #custom_gitmojis .. ' custom gitmoji(s) at the top')
  end

  -- Create entries from gitmojis
  local entries = {}
  for _, gitmoji in ipairs(gitmojis) do
    -- Handle semver (can be nil, vim.NIL, or a string)
    local semver_value = gitmoji.semver
    if semver_value == vim.NIL or semver_value == nil then
      semver_value = nil
    end
    local semver_text = semver_value and (' [' .. tostring(semver_value) .. ']') or ''
    local display = string.format('%s %s%s - %s', gitmoji.emoji, gitmoji.code, semver_text, gitmoji.description)

    table.insert(entries, {
      value = {
        emoji = gitmoji.emoji,
        code = gitmoji.code,
        description = gitmoji.description,
        name = gitmoji.name,
        semver = gitmoji.semver,
      },
      display = display,
      ordinal = gitmoji.code .. ' ' .. gitmoji.description .. ' ' .. gitmoji.name,
    })
  end

  -- Use cursor-relative theme
  local picker_opts = themes.get_cursor {
    prompt_title = opts.prompt_title or 'Gitmoji',
    finder = telescope.finders.new_table {
      results = entries,
      entry_maker = utils.create_entry_maker(),
    },
    sorter = telescope.conf.generic_sorter {},
    debounce = opts.debounce or 50,

    attach_mappings = function(prompt_bufnr, map)
      local actions = telescope.actions
      local action_state = telescope.action_state

      -- Default action: Insert gitmoji at cursor position in original buffer
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if selection and selection.value then
          local gitmoji = selection.value
          local text = gitmoji.emoji .. ' '

          actions.close(prompt_bufnr)

          -- Switch back to original buffer and insert text at captured position
          vim.schedule(function()
            vim.api.nvim_set_current_buf(original_bufnr)
            vim.api.nvim_set_current_win(original_win)
            insert_at_position(original_bufnr, original_row, original_col, text)
            -- Switch to insert mode after insertion
            vim.cmd 'startinsert'
            utils.notify_success('Inserted: ' .. gitmoji.emoji .. ' ' .. gitmoji.code)
          end)
        end
      end)
      -- Normal mode: 'c' to insert and open commit
      map('n', 'c', function()
        local selection = action_state.get_selected_entry()
        if selection and selection.value then
          local gitmoji = selection.value
          local text = gitmoji.emoji .. ' '
          actions.close(prompt_bufnr)
          vim.schedule(function()
            vim.api.nvim_set_current_buf(original_bufnr)
            vim.api.nvim_set_current_win(original_win)
            insert_at_position(original_bufnr, original_row, original_col, text)
            -- Switch to insert mode after insertion
            vim.cmd 'startinsert'
            utils.notify_success('Inserted: ' .. gitmoji.emoji .. ' ' .. gitmoji.code .. ' - Opening commit...')
            vim.cmd 'Git commit'
          end)
        end
      end)
      return true
    end,
  }
  -- Create picker with cursor theme
  telescope.pickers.new({}, picker_opts):find()
end

return M
