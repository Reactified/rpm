---------------------------------------
-- REACTIFIED PACKAGE MANAGER (RPM) --
-- github.com/Reactified/rpm        --
---------------------------------------

local function hash(str)
    -- simple hash function
    local int = 0
    for i = 1, #str do
        int = int + string.byte(string.sub(str,i,i))
    end
    return int
end

-- RPM Data
local data = {
    packages = {}
}
local function saveData()
    local f = fs.open("/.rpm","w")
    f.writeLine(textutils.serialise(data))
    f.close()
end
if not fs.exists("/.rpm") then
    saveData()
else
    local f = fs.open("/.rpm","r")
    data = textutils.unserialise(f.readAll())
    f.close()
end

-- RPM Functions
local distro = "https://raw.githubusercontent.com/Reactified/rpm/main/"
local function getFile(str)
    local h = http.get(distro..str)
    if h then
        local hdata = h.readAll()
        h.close()
        return hdata
    else
        return false
    end
end
local function parseManifest(manifest)
    local files = {}
    while true do
        local pos = string.find(manifest,"\n")
        local line = manifest
        if pos then
            line = string.sub(manifest,1,pos-1)
            manifest = string.sub(manifest,pos+1,#manifest)
        end
        line = string.gsub(line," ","")
        local pos2 = string.find(line,">")
        files[#files+1] = {string.sub(line,1,pos2-1),string.sub(line,pos2+1,#line)}
        if not pos then break end
    end
    return files
end
local function parseDependencies(dependencies)
    local files = {}
    while true do
        local pos = string.find(dependencies,"\n")
        local line = dependencies
        if pos then
            line = string.sub(dependencies,1,pos-1)
            dependencies = string.sub(dependencies,pos+1,#dependencies)
        end
        if #line > 2 then
            files[#files+1] = line
        end
        if not pos then break end
    end
    return files
end
local log = function() end
local function installPackage(package)
    if not package then
        log("failed: no package specified",true)
        return false,"no package specified"
    end

    if data.packages[package] then
        log("failed: "..package.." is already installed",true)
        return false,"package already installed"
    end

    log("searching for package...")
    local manifest = getFile("packages/"..package.."/manifest")
    if not manifest then
        log("failed: package not found",true)
        return false,"package not found"
    end
    log("located package "..package)

    local dependencies = getFile("packages/"..package.."/dependencies")

    if dependencies then
        print("downloading dependencies")
        dependencies = parseDependencies(dependencies)
        for id,dependency in pairs(dependencies) do
            if not data.packages[dependency] then
                installPackage(dependency)
            end
        end
    end

    local manifest = parseManifest(manifest)
    for id,file in pairs(manifest) do
        local fdata = getFile("packages/"..package.."/"..file[1])
        if fdata then
            log("+ PKG/"..file[1].." -> ~/"..file[2])
            f = fs.open(file[2],"w")
            f.writeLine(fdata)
            f.close()
            manifest[id][3] = hash(fdata)
        else
            log("PKG/"..file[1].." not found!",true)
        end
    end
    
    data.packages[package] = manifest
    saveData()
    log(package.." installed!")
end

-- RPM API
api = {
    install = function(package)
        installPackage(package)
        return true,"package installed"
    end,

    uninstall = function(package)
        if not package then
            log("failed: no package specified",true)
            return false,"no package specified"
        end

        if not data.packages[package] then
            log("failed: "..package.." is not installed",true)
            return false,"package not installed"
        end

        log("uninstalling "..package.."...")
        local manifest = data.packages[package]
        for id,file in pairs(manifest) do
            fs.delete(file[2])
            log("- ~/"..file[2])
        end
        
        data.packages[package] = nil
        saveData()
        log(package.." uninstalled!")
        return true,"package uninstalled"
    end,

    update = function(target_package)
        local packages_to_update = {target_package}
        if not target_package then
            for i,v in pairs(data.packages) do
                packages_to_update[#packages_to_update+1] = i
            end

            -- update RPM
            local f = fs.open(shell.getRunningProgram(),"r")
            local ndata = getFile("rpm.lua")
            if f and ndata then
                local fdata = f.readAll()
                f.close()
                if ndata ~= fdata then
                    log("rpm update available!")
                    log("updating rpm...")
                    sleep(3)
                    f = fs.open(shell.getRunningProgram(),"w")
                    f.writeLine(ndata)
                    f.close()
                else
                    log("rpm up to date")
                end
            else
                log("failed to update rpm")
            end
        end

        for _,package in pairs(packages_to_update) do
            log("updating "..package.."...")
            if not data.packages[package] then
                log("failed: "..package.." is not installed",true)
                return false,"package not installed"
            end

            local oldmanifest = data.packages[package]
            local manifest = getFile("packages/"..package.."/manifest")
            if not manifest then
                log("failed: could not fetch manifest",true)
                return false,"failed to fetch manifest"
            end

            local manifest = parseManifest(manifest)
            for id,file in pairs(manifest) do
                if not fs.exists(file[2]) then
                    local fdata = getFile("packages/"..package.."/"..file[1])
                    if fdata then
                        f = fs.open(file[2],"w")
                        f.writeLine(fdata)
                        f.close()
                        log("+ PKG/"..file[1].." -> ~/"..file[2])
                        manifest[id][3] = hash(fdata)
                    else
                        log("PKG/"..file[1].." not found!",true)
                    end
                end
            end

            for _,file in pairs(oldmanifest) do
                if fs.exists(file[2]) then
                    local fdata = getFile("packages/"..package.."/"..file[1])
                    if fdata then
                        if hash(fdata) ~= file[3] then
                            f = fs.open(file[2],"w")
                            f.writeLine(fdata)
                            f.close()
                            log("% PKG/"..file[1].." -> ~/"..file[2])
                            -- generate new hash
                            for id,v in pairs(manifest) do
                                if v[1] == file[1] and v[2] == file[2] then
                                    manifest[id][3] = hash(fdata)
                                end
                            end
                        else
                            -- set hash to old value
                            for id,v in pairs(manifest) do
                                if v[1] == file[1] and v[2] == file[2] then
                                    manifest[id][3] = file[3]
                                end
                            end
                        end
                    end
                end
            end

            data.packages[package] = manifest
            saveData()
            log(package.." up to date!")
        end
        return true,"up to date"
    end,

    list = function()
        local plist = {}
        for i,v in pairs(data.packages) do
            plist[#plist+1] = i
        end
        return plist
    end,
}

-- RPM Interface
if shell then

    log = function(str,err)
        if err then
            printError(str)
        else
            print(str)
        end
    end

    local methods = {
        help = function()
            print("available commands:")
            print("rpm help")
            print("rpm install <package>")
            print("rpm uninstall <package>")
            print("rpm update [package]")
            print("rpm list")
        end,
        install = function(package)
            api.install(package)
        end,
        uninstall = function(package)
            api.uninstall(package)
        end,
        update = function(package)
            api.update(package)
        end,
        list = function()
            print("installed packages:")
            for i,v in pairs(api.list()) do
                print("* "..v)
            end
        end,
    }

    local args = {...}
    if not args[1] or not methods[args[1]] then
        printError("invalid rpm command")
        printError("run 'rpm help' for help")
    else
        methods[args[1]](args[2],args[3],args[4])
    end

end
