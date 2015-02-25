local Emitter = require('core').Emitter
local Util = require('util')

local fs = require('fs')
local os = require('os')
local spawn = require('childprocess').spawn
local string = require('string')
local table = require('table')
local timer = require('timer')

local stats = {
  ['VmPeak'] = true, 
  ['VmSize'] = true,
  ['VmLck'] = true,
  ['VmPin'] = true,
  ['VmHWM'] = true,
  ['VmRSS'] = true,
  ['VmData'] = true,
  ['VmStk'] = true,
  ['VmExe'] = true,
  ['VmLib'] = true,
  ['VmPTE'] = true,
  ['VmSwap'] = true,
  ['Threads'] = true,
  ['voluntary_ctxt_switches'] = true,
  ['nonvoluntary_ctxt_switches'] = true
}

-- monkey patch string
string.split = Util.split

local PidStatus = Emitter:extend()

-- constructor
function PidStatus:initialize(name)
  self.name = name
  self.pid = nil

  -- using /proc so check for linux
  if os.type() == 'Linux' then
    self.statTimer = timer.setInterval(1000, function ()
      self:getStatus()
    end)

    self:getPid()
  end
end

-- get process id
function PidStatus:getPid()
  child = spawn('bash', { '-c','pidof ' .. self.name})

  child.stdout:on('data', function(chunk)
    if chunk then
      self.pid = chunk:sub(0, -2)
    end
  end)
end

-- parse /proc/<id>/status file
function PidStatus:getStatus()
  if self.pid then
    local statfile = '/proc/' .. self.pid .. '/status'
  
    if fs.existsSync(statfile) then
      status = fs.readFileSync(statfile)
      parts = string.split(status, "\n")

      for index,value in ipairs(parts) do
        kv = string.split(value, ":\t")
        if table.getn(kv) == 2 and stats[kv[1]] then
          self:emit('status', {name=kv[1],value=self.formatValue(kv[2])})
        end
      end
    else
      -- TODO probably a better way to handle this
      self:getPid()
    end
  end
end

PidStatus.formatValue = function(val)
  fval = val:gsub("%s+", '')
  fval = val:gsub('kB', '')
  
  if val:find('kB') then
    fval = fval * 1024
  end

  return fval
end

-- export
return PidStatus
