--[[
  Credit: most of the logic for this module is ported from here:
  https://github.com/lucagrulla/node-tail
--]]

local Emitter = require('core').Emitter
local Watcher = require('uv').Watcher
local Util = require('util')

local fs = require('fs')

local string = require('string')
local table = require('table')
local timer = require('timer')

-- monkey patch string
string.split = Util.split

local Tail = Emitter:extend()

-- constructor
function Tail:initialize(filename, separator)
  self.filename = filename
  self.separator = separator

  self.buffer = ''
  self.queue = {}

  self.internalDispatcher = Emitter:new()
  self.isWatching = false
  
  self.internalDispatcher:on('next', function ()
    self:readBlock()
  end)

  self.pos = fs.statSync(self.filename).size
  self:watch()
end

function Tail:readBlock()
  if table.getn(self.queue) >= 1 then
    block = table.remove(self.queue, 1)
    
    if block.stop > block.start then
      length = block.stop - block.start
      stream = fs.createReadStream(self.filename, {offset=block.start, length=length})

      stream:on('error', function(error)
        debug("Tail error:" .. error)
        self:emit('error', error)
      end)

      stream:on('end', function()
        if table.getn(self.queue) >= 1 then
          self.internalDispatcher:emit("next")
        end
      end)

      stream:on('data', function (chunk, len)
        self.buffer = self.buffer .. chunk
        
        -- TODO this is not ideal
        parts = string.split(self.buffer, self.separator, nil)
        
        self.buffer = table.remove(parts)

        for index,value in ipairs(parts) do
          self:emit('line', value)
        end
      end)
    end
  end
end

function Tail:watch()
  if not self.isWatching then
    self.isWatching = true

    self.watcher = Watcher:new(self.filename)

    self.watcher:on('change', function(event, filename)
      self:watchEvent(event, filename)
    end)
    self.watcher:on('rename', function(event, filename)
      self:watchEvent(event, filename)
    end)
  end
end

function Tail:unwatch()
  self.watcher:close()
  self.pos = 0
  self.isWatching = false
  self.queue = {}
end

function Tail:watchEvent(event, path)
  if event == 'change' then
    stats = fs.statSync(self.filename)
    if stats.size < self.pos then
      self.pos = stats.size 
    end
    if stats.size > self.pos then
      table.insert(self.queue, {start=self.pos, stop=stats.size})
      self.pos = stats.size
      if  table.getn(self.queue) == 1 then
        self.internalDispatcher:emit("next")
      end
    end
  end
  if event == 'rename' then
    self:unwatch()
    timer.setTimeout(1000, function()
      self:watch()
    end)
  end
end

-- exports
return Tail
