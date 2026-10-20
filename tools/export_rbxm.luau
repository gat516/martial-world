--!nocheck
-- Full-fidelity export of an instance tree to a binary .rbxm (keeps every
-- property, attributes and tags, unlike export_rbxmx.luau). Use it for VFX, whose
-- plugin settings (EmitCount, EmitDelay, ...) live in attributes. Run this file
-- once through the Studio MCP's execute_luau: it installs
-- _G.exportRbxm(path, rootName?), which returns the file as base64. With
-- tools/receive_rbxmx.py running:
--   game:GetService("HttpService"):PostAsync("http://127.0.0.1:8766/Effects.rbxm",
--     _G.exportRbxm("ReplicatedStorage._StagingEffects", "Effects"))
-- writes tools/frag/Effects.rbxm. rootName renames the root in the file (a
-- staging copy exported under the real name); the instance in Studio is untouched.

local SerializationService = game:GetService("SerializationService")

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64(b: buffer): string
	local out = table.create(math.ceil(buffer.len(b) / 3))
	local n = buffer.len(b)
	for i = 0, n - 1, 3 do
		local a = buffer.readu8(b, i)
		local c1 = if i + 1 < n then buffer.readu8(b, i + 1) else 0
		local c2 = if i + 2 < n then buffer.readu8(b, i + 2) else 0
		local v = a * 65536 + c1 * 256 + c2
		local s = {}
		for k = 3, 0, -1 do
			local idx = bit32.band(bit32.rshift(v, k * 6), 63) + 1
			table.insert(s, ALPHABET:sub(idx, idx))
		end
		if i + 1 >= n then
			s[3], s[4] = "=", "="
		elseif i + 2 >= n then
			s[4] = "="
		end
		table.insert(out, table.concat(s))
	end
	return table.concat(out)
end

_G.exportRbxm = function(target: string, rootName: string?): string
	local node = game
	for part in string.gmatch(target, "[^%.]+") do
		node = node:FindFirstChild(part) or game:GetService(part)
	end
	local root = node
	if rootName and rootName ~= node.Name then
		root = node:Clone()
		root.Name = rootName
	end
	local ok, result = pcall(SerializationService.SerializeInstancesAsync, SerializationService, { root })
	if root ~= node then
		root:Destroy()
	end
	assert(ok, result)
	return base64(result)
end
return "exportRbxm installed"
