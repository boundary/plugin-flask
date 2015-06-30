local Emitter = require('core').Emitter
local PidStatus = require('pidstatus')
local Tail = require('tail')
local Util = require('util')

local string = require('string')
local table = require('table')

local stats = {
  ['BC'] = {
    ['name'] = 'FLASK_BLOCKS',
    ['type'] = 'number'
  },
  ['BM'] = {
    ['name'] = 'FLASK_BLOCKS_MEMORY',
    ['type'] = 'bytes'
  },
  ['BFC'] = {
    ['name'] = 'FLASK_BLOCKS_FILES',
    ['type'] = 'number'
  },
  ['BCO'] = {
    ['name'] = 'FLASK_BLOCKS_WRITTEN',
    ['type'] = 'number'
  },
  ['BBT'] = {
    ['name'] = 'FLASK_BLOCKS_TOSSED',
    ['type'] = 'number'
  },
  ['PI'] = {
    ['name'] = 'FLASK_DATA_POINTS_IN',
    ['type'] = 'number'
  },
  ['PO'] = {
    ['name'] = 'FLASK_DATA_POINTS_OUT',
    ['type'] = 'number'
  },
  ['SC'] = {
    ['name'] = 'FLASK_CONNECTIONS',
    ['type'] = 'number'
  },
  ['STC'] = {
    ['name'] = 'FLASK_CURRENT_CONNECTIONS',
    ['type'] = 'number'
  },
  ['SD'] = {
    ['name'] = 'FLASK_DISCONNECTIONS',
    ['type'] = 'number'
  },
  ['SR'] = {
    ['name'] = 'FLASK_REQUESTS',
    ['type'] = 'number'
  },
  ['QBL'] = {
    ['name'] = 'FLASK_QUEUE_BACKLOG',
    ['type'] = 'number'
  },
  ['VmSize'] = {
    ['name'] = 'FLASK_MEMORY_VIRT',
    ['type'] = 'bytes'
  },
  ['VmRSS'] = {
    ['name'] = 'FLASK_MEMORY_RSS',
    ['type'] = 'bytes'
  },
  ['Threads'] = {
    ['name'] = 'FLASK_THREADS',
    ['type'] = 'number'
  },
  ['voluntary_ctxt_switches'] = {
    ['name'] = 'FLASK_CTX_SW',
    ['type'] = 'number'
  }
}

-- monkey patch string
string.split = Util.split

local Flask = Emitter:extend()

-- constructor
function Flask:initialize(filename)
  self.filename = filename
  self.separator = "\n"

  -- log processor
  self.tail = Tail:new(self.filename, "\n")

  self.tail:on("error", function(error)
    error(error)
  end)

  self.tail:on("line", function(line)
    self:parse(line)
  end)

  -- process status
  self.process = PidStatus:new('/opt/flask/bin/flask')
  self.process:on("status", function(status)
    self:filter(status)
  end)
end

-- parse the flask log lines
function Flask:parse(line)
  if line ~= '' and line:find('|') ~= nil then
    metrics = string.split(line, ' ')

    for index,value in ipairs(metrics) do
      metric = string.split(value, '|')

      if table.getn(metric) == 2 then
        stat = stats[metric[1]]
        if stat then
          name, value = stat.name, metric[2]

          if stat.type == 'bytes' then
            value = self.valueScrub(value)
          end
          self:emit('metric', {name=stat.name,value=value})
        end
      end
    end
  end 
end

-- filter process metrics
function Flask:filter(status)
  stat = stats[status.name]
  if stat then
    self:emit('metric', {name=stat.name,value=status.value})
  end
end

-- scrub byte values
Flask.valueScrub = function(value)
  if value:find('gb') then
    value = value:gsub('gb', '') * 1024 * 1024 * 1024
  elseif value:find('mb') then
    value = value:gsub('mb', '') * 1024 * 1024
  elseif value:find('kb') then
    value = value:gsub('mb', '') * 1024
  elseif value:find('b') then
    value = value:gsub('b', '')
  end
  
  return value
end

-- exports
return Flask
