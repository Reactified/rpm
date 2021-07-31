-- API written by SpaceCat Chan
-- thank you -React
local api = {}
api.admin = {}

api.meta = {}

local server_address

function api.meta.set_server_address(address)
    server_address = address
    if api.backend then
        api.backend.set_server_address(address)
    end
end

function api.meta.force_backend(backend)
    api.backend = backend
    api.backend.set_server_address(server_address)
end

---@param name string
---@return integer|nil, integer, any
function api.get_bal(name)
    local response_code, response = api.backend.request("GET", "v1/user/balance?name="..name)

    local bal
    if response_code == 200 then
        bal = response
    end

    return bal, response_code, response
end

---@class log_entry
---@field from string
---@field to string
---@field amount integer
---@field time integer
local ignore_1

---@param name string
---@param password string
---@return log_entry[]|nil, integer, any
function api.get_log(name, password)
    local response_code, response = api.backend.request("GET", "v1/user/log", {name = name, password = password})
    
    local log
    if response_code == 200 then
        log = response
    end
    
    return log, response_code, response
end

---@param name string
---@param password string
---@param target string
---@param amount integer
---@return integer|nil, integer, any
function api.send_funds(name, password, target, amount)
    local response_code, response = api.backend.request("POST", "v1/user/transfer",
                                                        {name=name,password=password},
                                                        {{name=target},{amount=amount}})

    local new_bal
    if response_code == 200 then
        new_bal = response
    end
    return new_bal, response_code, response
end

---@param name string
---@param password string
---@return boolean, integer, any
function api.verify_password(name, password)
    local response_code, response = api.backend.request("POST", "v1/user/verify_password", {name=name, password=password})
    return response_code == 204, response_code, response
end


---@param name string
---@param old_password string
---@param new_password string
---@return boolean, integer, any
function api.change_password(name, old_password, new_password)
    local response_code, response = api.backend.request("PATCH", "v1/user/change_password",
                                                        {name=name, password=old_password},
                                                        {{pass=new_password}})
    return response_code == 204, response_code, response
end

---@param admin_name string
---@param admin_password string
---@param user_name string
---@param new_user_password string
---@return boolean, integer, any
function api.admin.change_password(admin_name, admin_password, user_name, new_user_password)
    local response_code, response = api.backend.request("PATCH", "v1/admin/user/change_password",
                                                        {name=admin_name, password=admin_password},
                                                        {{name=user_name}, {pass=new_user_password}})
    return response_code == 204, response_code, response
end

---@param admin_name string
---@param admin_password string
---@param user_name string
---@param new_bal integer
---@return boolean, integer, any
function api.admin.set_bal(admin_name, admin_password, user_name, new_bal)
    local response_code, response = api.backend.request("PATCH", "v1/admin/set_balance",
                                                        {name=admin_name, password=admin_password},
                                                        {{name=user_name}, {amount=new_bal}})
    return response_code == 204, response_code, response
end

---@param admin_name string
---@param admin_password string
---@param user_name string
---@param amount integer
---@return integer|nil, integer, any
function api.admin.impact_bal(admin_name, admin_password, user_name, amount)
    local response_code, response = api.backend.request("POST", "v1/admin/impact_balance",
                                                        {name=admin_name, password=admin_password},
                                                        {{name=user_name}, {amount=amount}})
    local new_bal
    if response_code == 200 then
        new_bal = response
    end
    return new_bal, response_code, response
end


---@param admin_name string
---@param admin_password string
---@return boolean, integer, any
function api.admin.close(admin_name, admin_password)
    local response_code, response = api.backend.request("POST", "v1/admin/shutdown", {name=admin_name, password=admin_password})
    return response_code == 204, response_code, response
end

---@param name string
---@return boolean, integer, any
function api.user_exists(name)
    local response_code, response = api.backend.request("GET", "v1/user/exists?name="..name)
    return response_code == 204, response_code, response
end

---@param admin_name string
---@param admin_password string
---@return boolean, integer, any
function api.admin.verify_password(admin_name, admin_password)
    local response_code, response = api.backend.request("POST", "v1/admin/verify_account", {name=admin_name, password=admin_password})
    return response_code == 204, response_code, response
end

---@param admin_name string
---@param admin_password string
---@param amount integer
---@param opt_time nil|integer
---@return integer|nil, integer, any
function api.admin.prune_users(admin_name, admin_password, amount, opt_time)
    local response_code, response = api.backend.request("POST", "v1/admin/prune_users",
                                                        {name=admin_name, password=admin_password},
                                                        {{amount=amount}, {time=opt_time}})
    local amount_deleted
    if response_code == 200 then
        amount_deleted = response
    end
    return amount_deleted, response_code, response
end

---@class properties
---@field version integer
---@field max_log integer
---@field return_on_del string|nil
local ignore_2

---@return properties|nil
function api.properties()
    local response_code, response = api.backend.request("GET", "properties")

    local properties
    if response_code == 200 then
        properties = response
    end
    return properties, response_code, response
end


---@param name string
---@param password string
---@return boolean, integer, any
function api.register(name, password)
    local response_code, response = api.backend.request("POST", "v1/user/register",
                                                        nil,
                                                        {{name=name}, {pass=password}})
    return response_code == 204, response_code, response
end

---@param admin_name string
---@param admin_password string
---@param name string
---@param password string
---@param balance integer
---@return boolean, integer, any
function api.admin.create_user(admin_name, admin_password, name, password, balance)
    local response_code, response = api.backend.request("POST", "v1/admin/user/register",
                                                        {name=admin_name, password=admin_password},
                                                        {{name=name}, {amount=balance}, {pass=password}})

    return response_code == 204, response_code, response
end

---@param name string
---@param password string
---@return boolean, integer, any
function api.delete_self(name, password)
    local response_code, response = api.backend.request("DELETE", "v1/user/delete", {name=name, password=password})
    return response_code == 204, response_code, response
end

---@param admin_name string
---@param admin_password string
---@param user_name string
---@return boolean, integer, any
function api.admin.delete_user(admin_name, admin_password, user_name)
    local response_code, response = api.backend.request("DELETE", "v1/admin/user/delete",
                                                        {name=admin_name, password=admin_password},
                                                        {{name=user_name}})
    return response_code == 204, response_code, response
end

if term then
    local computercraft = dofile("/apis/ccash/backends/computercraft.lua")
    api.meta.force_backend(computercraft)
else
    if not CCASH_IGNORE_UNSUPPORTED_ENVIRONMENT then
        error("non-computercraft environments are not currently supported\n(set global CCASH_IGNORE_UNSUPPORTED_ENVIRONMENT to true to ignore)")
    end
end

return api
