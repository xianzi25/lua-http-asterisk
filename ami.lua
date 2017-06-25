local byte = string.byte
local tcp = ngx.socket.tcp
local null = ngx.null
local type = type
local assert = assert
local tostring = tostring
local pairs = pairs
local setmetatable = setmetatable
local rawget = rawget

local ASTERISK_BANNER = "^Asterisk Call Manager/(%d.%d)"

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 54)

_M._VERSION = '0.1'

local common_cmds = {
	"Ping",
	--[["Login",]]
	"Logoff",
	"Originate",
	"Redirect",
	"Setvar",
	"Getvar",
	"Hangup",
	"Command",
	"Bridge",
	"Park"
}

local mt = { __index = _M }
function _M.new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    return setmetatable({ _sock = sock }, mt)
end

function _M.set_timeout(self, timeout)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:settimeout(timeout)
end

function _M.connect(self, ...)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:connect(...)
end

function _M.set_keepalive(self, ...)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:setkeepalive(...)
end

function _M.get_reused_times(self)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:getreusedtimes()
end

local function close(self)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:close()
end
_M.close = close


local function _parse_line(line)
	local k,v = line:match("^(.-):%s*(.+)$")
	if not k then
		return nil ,"parse error,malfomed line"
	end
	return k,v
end

local function _build_request(action,data)
	local packet = 'Action: '..action
	packet = { packet }	
	for k,v in pairs(data) do
		--assert(type(k)=="string", "k is not a string")
		--assert(type(v)=="string", "v is not a string")
		packet[#packet + 1] = k..": "..v
	end
	packet = table.concat(packet,"\r\n")
	packet = packet.."\r\n\r\n"

	return packet
end

local function _read_reply(self)
	--assert(type(slef) == "table" )
	local sock = rawget(self, "_sock")
	if not sock then
		return nil,"not initialized"
	end

	local t = {}
	while true do
		local line,err = sock:receive()
		if not line then
			return nil,err
		end

		if #line == 0 then
			return t
		end

		local k,v = _parse_line(line)
		if k then
			if t[k] then
				if type(t[k]) ~= "table" then
					t[k]= {t[k]}
				end
				t[k][#t + 1]= v
			else
				t[k] = v 
			end
		else
			local err = v 
			return nil ,err
		end
	end
end


local function _check_reply(response,field)
	local tmp_field = field or "Message"
	assert(type(response)=="table", "response is not a table")
	if field then
		assert(type(field)=="string", "field is not a string or nil")
	end

	if response and response.Response == "Success" then
		if response[tmp_field] then
			return tostring(response[tmp_field])
		else
			return nil, "Reply structure miss required field: " ..tmp_field
		end
	end

	if response and response.Response == "Error" then
		return nil, tostring(response.Message) or "unknown AMI failure"
	end

	return nil, "malformed reply"
end




local function _do_cmd(self, action,data)
	local sock = rawget(self,"_sock")
	if not sock then
		return nil,"not initialized"
	end

	local req = _build_request(action,data)
	local bytes,err = sock:send(req)	
	if not bytes then
		return nil,err
	end
	--return _check_reply( _read_reply(self),check_field)
	return  _read_reply(self)
end

function _M.Login(self, user, secret )
	local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end
	local banner, err = sock:receive()
	if err then
		return nil,err
	end
	local protocol_version = banner:match(ASTERISK_BANNER)
	if not protocol_version then
		sock:close()
		return nil, "bad signature: " .. banner
	end

	--return _do_cmd(self,"Login",{Username= user;Secret= secret; Events="off"})
	local resp,err _do_cmd(self,"Login",{Username= user;Secret= secret; Events="off"})
	if resp.Response == 'Success' then
		
	end
end


--[[
local function  simple_login(conn, user, secret)
	assert(type(conn)=="table", "conn is not a table (connection object)")
	assert(type(user)=="string", "user is not a string")
	assert(type(secret)=="string", "secret is not a string")

	local result, err = conn:command(
      "Login",
      {
        Username = user;
        Secret = secret;
      }
    )
  if not result then
    return nil, err
  end
  result, err = conn:get_reply()
  if not result then
    return nil, err
  end
  return check_reply(result)
end
--]]
--
for i = 1, #common_cmds do
    local cmd = common_cmds[i]

    _M[cmd] =
        function (self, ...)
            return _do_cmd(self, cmd, ...)
        end
end

-- this method is deperate since we already do lazy method generation.
function _M.add_commands(...)
    local cmds = {...}
    for i = 1, #cmds do
        local cmd = cmds[i]
        _M[cmd] =
            function (self, ...)
                return _do_cmd(self, cmd, ...)
            end
    end
end

setmetatable(_M, {__index = function(self, cmd)
    local method =
        function (self, ...)
            return _do_cmd(self, cmd, ...)
        end

	-- cache the lazily generated method in our
	-- module table
    _M[cmd] = method
    return method
end})

return _M
