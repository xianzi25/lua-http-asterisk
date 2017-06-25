# lua-http-asterisk
用于将asterisk的常见短操作，包一层http操作接口

# demo

local ami = require "resty.ami"
local say =ngx.say

local am_client = ami:new()
am_client:set_timeout(10000)
local ok,err = amic:connect("127.0.0.1",5038)
if not ok then
	say('fail to connect ',err)
else
	say('tcp connect succ')
end

local count,err = am_client:get_reused_times()
if 0 == count then
	ok,err = am_client:Login('admin','scret_of_admin')
	if not ok then
		say('Login fail ',err)
	else
		say('Login status : ',ok.Response,", ",ok.Message)
	end
elseif err then
	say('fail to get reuse result ',err)
else 
	say('connect count  > 0 ,is ',count)
end

say('hello ',count)
local result_ping,err=am_client:Ping({})
if result_ping then
	say('ping result is : ',result_ping)
else
	say('ping result is null ',err)
end

