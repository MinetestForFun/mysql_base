local modname = minetest.get_current_modname()
local thismod = _G[modname]

---- Table creation & deletion

function thismod.create_table_sql(name, params)
  local lines = {}
  for _, coldata in ipairs(params.columns) do
    local line = (coldata.name or coldata[1]) .. ' ' .. (coldata.type or coldata[2])
    if coldata.notnull then
      line = line .. ' NOT NULL'
    end
    if coldata.default then
      line = line .. ' DEFAULT ' .. coldata.default
    end
    if coldata.autoincrement then
      line = line .. ' AUTO_INCREMENT'
    end
    table.insert(lines, line)
  end
  table.insert(lines, 'PRIMARY KEY (' .. table.concat(params.pkey, ',') .. ')')
  for fkeyname, fkeydata in pairs(params.fkeys or {}) do
    table.insert(lines, 'FOREIGN KEY (' .. fkeyname .. ') REFERENCES ' .. fkeydata.table ..
        '(' .. fkeydata.column .. ')')
  end
  for _, ucol in pairs(params.unique or {}) do
    if type(ucol) == 'table' then
      table.insert(lines, 'UNIQUE (' .. table.concat(ucol, ',') .. ')')
    else
      table.insert(lines, 'UNIQUE (' .. ucol .. ')')
    end
  end
  return 'CREATE TABLE ' .. name .. ' (' .. table.concat(lines, ',') .. ')'
end

function thismod.create_table(name, params)
  thismod.conn:query(thismod.create_table_sql(name, params))
end

function thismod.drop_table_sql(name)
  return 'DROP TABLE ' .. name
end

function thismod.drop_table(name)
  thismod.conn:query(thismod.drop_table_sql(name))
end

---- INSERT prepare

function thismod.prepare_insert_sql(tablename, colnames)
  local qmarks = {}
  for i = 1, #colnames do
    qmarks[i] = '?'
  end
  return 'INSERT INTO ' .. tablename .. '(' .. table.concat(colnames, ',') .. ') VALUES (' ..
      table.concat(qmarks, ',') .. ')'
end
function thismod.prepare_insert(tablename, cols)
  local colnames, coltypes = {}, {}
  for _, col in ipairs(cols) do
    table.insert(colnames, col.name or col[1])
    table.insert(coltypes, col.type or col[2])
  end
  local stmt = thismod.conn:prepare(thismod.prepare_insert_sql(tablename, colnames))
  return stmt, stmt:bind_params(coltypes)
end

---- UPDATE prepare

function thismod.prepare_update_sql(tablename, colnames, where)
  return 'UPDATE ' .. tablename .. ' SET ' .. table.concat(colnames, ',') .. ' WHERE ' .. where
end
function thismod.prepare_update(tablename, cols, where, wheretypes)
  local colnames, paramtypes = {}, {}
  for _, col in ipairs(cols) do
    table.insert(colnames, (col.name or col[1]) .. '=' .. (col.value or '?'))
    if col.type or col[2] then
      table.insert(paramtypes, col.type or col[2])
    end
  end
  for _, wheretype in ipairs(wheretypes) do
    table.insert(paramtypes, wheretype)
  end
  local stmt = thismod.conn:prepare(thismod.prepare_update_sql(tablename, colnames, where))
  return stmt, stmt:bind_params(paramtypes)
end

---- DELETE prepare

function thismod.prepare_delete(tablename, where, wheretypes)
  local stmt = thismod.conn:prepare('DELETE FROM ' .. tablename .. ' WHERE ' .. where)
  return stmt, stmt:bind_params(wheretypes)
end

---- SELECT prepare

function thismod.prepare_select_sql(tablename, colnames, where)
  return 'SELECT ' .. table.concat(colnames, ',') .. ' FROM ' .. tablename .. ' WHERE ' .. where
end

function thismod.prepare_select(tablename, cols, where, wheretypes)
  local colnames, coltypes = {}, {}
  for _, col in ipairs(cols) do
    table.insert(colnames, col.name or col[1])
    table.insert(coltypes, col.type or col[2])
  end
  local stmt = thismod.conn:prepare(thismod.prepare_select_sql(tablename, colnames, where))
  return stmt, stmt:bind_params(wheretypes), stmt:bind_result(coltypes)
end