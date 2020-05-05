local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

local thismod = {
  enabled = false,
}
_G[modname] = thismod

function thismod.mklog(level, modname)
  return function(str)
    minetest.log(level, "[" .. modname .. "] " .. str)
  end
end

local LogI = thismod.mklog('action', modname)
local LogE = thismod.mklog('error', modname)

local singleplayer = minetest.is_singleplayer() -- Caching is OK since you can't open a game to
-- multiplayer unless you restart it.

if minetest.settings:get(modname .. '.enable_singleplayer') ~= 'true' and singleplayer then
  LogI("Not enabling because of singleplayer game")
  return
end

thismod.enabled = true

local function setoverlay(tab, orig)
  local mt = getmetatable(tab) or {}
  mt.__index = function (tab, key)
    if rawget(tab, key) ~= nil then
      return rawget(tab, key)
    else
      return orig[key]
    end
  end
  setmetatable(tab, mt)
end

local insecrequire = _G.require
local ffi, bit
do
  if minetest.request_insecure_environment then
    insecrequire = minetest.request_insecure_environment().require
    LogI("Fetched require() from insecure env")
  end
  local test_fn = function()
    return { require('ffi'), require('bit') }
  end
  local env = { require = insecrequire }
  setoverlay(env, _G)
  setfenv(test_fn, env)
  local ffi_ok, ret = pcall(test_fn)
  if not ffi_ok then
    error("Cannot access LuaJIT FFI. Either you are not using LuaJIT, or mod security is enabled" ..
          " and mysql_base is not an exception.")
  end
  ffi, bit = unpack(ret)
end

local function string_splitdots(s)
  local temp = {}
  local index = 0
  local last_index = string.len(s)
  while true do
    local i, e = string.find(s, '%.', index)
    if i and e then
      local next_index = e + 1
      local word_bound = i - 1
      table.insert(temp, string.sub(s, index, word_bound))
      index = next_index
    else
      if index > 0 and index <= last_index then
        table.insert(temp, string.sub(s, index, last_index))
      elseif index == 0 then
        temp = nil
      end
      break
    end
  end
  return temp
end

local mysql
do -- MySQL module loading
  local env = {}
  setoverlay(env, _G)
  local function secexec(path)
    local fn, msg = loadfile(path)
    if not fn then error(msg) end
    setfenv(fn, env)
    local status, ret = pcall(fn, {})
    if not status then
      error(ret)
    end
    return ret
  end
  local function secrequire(module)
    if module == 'mysql_h' then
      return secexec(modpath .. '/mysql/mysql_h.lua')
    elseif module == 'ffi' then
      return ffi
    elseif module == 'bit' then
      return bit
    else
      error("mysql.lua tried to require('" .. module .. "')")
    end
  end
  env.require = secrequire
  local status
  status, mysql = pcall(secexec, modpath .. '/mysql/mysql.lua')
  if not status then
    error(modname .. ' failed to load MySQL FFI interface: ' .. tostring(mysql))
  end
  thismod.mysql = mysql
end

function thismod.mkget(modname)
  local get
  if minetest.settings then
    get = function (name) return minetest.settings:get(modname .. '.' .. name) end
  else
    get = function (name) return minetest.setting_get(modname .. '.' .. name) end
  end
  local cfgfile = get('cfgfile')
  if type(cfgfile) == 'string' and cfgfile ~= '' then
    local file = io.open(cfgfile, 'rb')
    if not file then
      error(modname .. ' failed to load specified config file at ' .. cfgfile)
    end
    local cfg, msg = minetest.deserialize(file:read('*a'))
    file:close()
    if not cfg then
      error(modname .. ' failed to parse specified config file at ' .. cfgfile .. ': ' .. msg)
    end
    get = function (name)
      if type(name) ~= 'string' or name == '' then
        return nil
      end
      local parts = string_splitdots(name)
      if not parts then
        return cfg[name]
      end
      local tbl = cfg[parts[1]]
      for n = 2, #parts do
        if tbl == nil then
          return nil
        end
        tbl = tbl[parts[n]]
      end
      return tbl
    end
  end
  return get
end

local get = thismod.mkget(modname)
do
  local conn, dbname
  -- MySQL API backend
  mysql.config(get('db.api'))

  local connopts = get('db.connopts')
  if (get('db.db') == nil) and (type(connopts) == 'table' and connopts.db == nil) then
    error(modname .. ": missing database name parameter")
  end
  if type(connopts) ~= 'table' then
    connopts = {}
    -- Traditional connection parameters
    connopts.host, connopts.user, connopts.port, connopts.pass, connopts.db =
      get('db.host') or 'localhost', get('db.user'), get('db.port'), get('db.pass'), get('db.db')
  end
  connopts.charset = 'utf8'
  connopts.options = connopts.options or {}
  connopts.options.MYSQL_OPT_RECONNECT = true
  conn = mysql.connect(connopts)
  dbname = connopts.db
  LogI("Connected to MySQL database " .. dbname)
  thismod.conn = conn
  thismod.dbname = dbname

  -- LuaPower's MySQL interface throws an error when the connection fails, no need to check if
  -- it succeeded.

  -- Ensure UTF-8 is in use.
  -- If you use another encoding, kill yourself (unless it's UTF-32).
  conn:query("SET NAMES 'utf8'")
  conn:query("SET CHARACTER SET utf8")
  conn:query("SET character_set_results = 'utf8', character_set_client = 'utf8'," ..
                  "character_set_connection = 'utf8', character_set_database = 'utf8'," ..
                  "character_set_server = 'utf8'")

  local set = function(setting, val) conn:query('SET ' .. setting .. '=' .. val) end
  pcall(set, 'wait_timeout', 3600)
  pcall(set, 'autocommit', 1)
  pcall(set, 'max_allowed_packet', 67108864)
end

local function ping()
  if thismod.conn then
    if not thismod.conn:ping() then
      LogE('error', modname .. ": failed to ping database")
    end
  end
  minetest.after(1800, ping)
end

minetest.after(10, ping)

local shutdown_callbacks = {}
function thismod.register_on_shutdown(func)
  table.insert(shutdown_callbacks, func)
end

minetest.register_on_shutdown(function()
  if thismod.conn then
    LogI("Shutting down, running callbacks")
    for _, func in ipairs(shutdown_callbacks) do
      func()
    end
    thismod.conn:close()
    thismod.conn = nil
    LogI("Closed database connection")
  end
end)

function thismod.table_exists(name)
  thismod.conn:query("SHOW TABLES LIKE '" .. name .. "'")
  local res = thismod.conn:store_result()
  local exists = (res:row_count() ~= 0)
  res:free()
  return exists
end

dofile(modpath .. '/abstraction.lua')