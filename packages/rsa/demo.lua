os.loadAPI("/apis/rsa.lua")

local f = io.open("/public.key", "r")
local publicKey = textutils.unserialize(f:read("*a"))
f:close()
f = io.open("/private.key", "r")
local privateKey = textutils.unserialize(f:read("*a"))
f:close()

local byteSize = 8
local bits = 256

local msg = "hello" -- Maximum message size is bits / byteSize

local startTime = os.clock()
-- Encrypting
local res = rsa.bytesToNumber(stringToBytes(msg), bits, byteSize)
local encrypted = rsa.crypt(publicKey, res)
print("Took " .. os.clock() - startTime .. " seconds to encrypt.")

-- You may transmit "encrypted" in public. "encrypted" is a string.

sleep(0.1)
startTime = os.clock()
-- Decrypting
local decrypted = rsa.crypt(privateKey, encrypted)
local decryptedBytes = rsa.numberToBytes(decrypted, bits, byteSize)
print("Took " .. os.clock() - startTime .. " seconds to decrypt.")
print(rsa.bytesToString(decryptedBytes))
