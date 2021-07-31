local JSON = dofile("/apis/ccash/backends/JSON.lua")

JSON.onDecodeError = function() end
JSON.onDecodeOfHTMLError = function() end

local backend = {}

local server_address

---@param address string
function backend.set_server_address(address)
    if address then
        if not address:sub(#address, #address) == "/" then
            server_address = address.."/"
        else
            server_address = address
        end
    end
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
-- encoding
local function enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

---@class auth
---@field name string
---@field password string
local ignore_1

---@param method string
---@param url string
---@param auth auth|nil
---@param body any
---@return integer, any
function backend.request(method, url, auth, body)
    local headers = {Accept = "application/json", ["Content-Type"] = "application/json"}
    if auth then
        headers["Authorization"] = "Basic "..enc(auth.name..":"..auth.password)
    end
    local timer = os.startTimer(10)
    local enc_body
    if body then
        enc_body = "{"
        for _,v in ipairs(body) do
            local k,vv = next(v)
            if type(vv) == "string" then
                enc_body = enc_body.."\""..k.."\":\""..vv.."\","

            else
                enc_body = enc_body.."\""..k.."\":"..tostring(vv)..","
            end
        end
        enc_body = enc_body:sub(0, #enc_body-1)
        enc_body = enc_body.."}"
    end
    local full_url = server_address.."api/"..url
    http.request({method = method, url = full_url, headers = headers, body = enc_body})
    while true do
        local event, url_or_id, handle_or_err_body, err_handle = os.pullEvent()
        if event == "timer" and url_or_id == timer then
            return 0, {message = "timed out"}
        elseif event == "http_success" and url_or_id == full_url then
            return handle_or_err_body.getResponseCode(), JSON:decode(handle_or_err_body.readAll())
        elseif event == "http_failure" and url_or_id == full_url then
            if err_handle then
                local all_text = err_handle.readAll()
                return err_handle.getResponseCode(), JSON:decode(all_text) or all_text
            else
                return 0, "unknown error"
            end
        end
    end
end

return backend
