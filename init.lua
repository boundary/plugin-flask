local fs = require('fs')
local json = require('json')
local os = require('os')
local string = require('string')

local Flask = require('flask')

local _param = json.parse(fs.readFileSync('param.json')) or {}
local _source = _param.source or os.hostname()

if not _param.logPath then
  print('Flask log path is not set')
  process.exit(1)
end

if not fs.existsSync(_param.logPath) then
  print('Specified log path does not exist')
  process.exit(1)
end

print("_bevent:Boundary Flask plugin up : version 1.0|t:info|tags:lua,plugin")

flask = Flask:new(_param.logPath)

flask:on('metric', function(metric)
  p(string.format("%s %f %s", metric.name, metric.value, _source))
end)
