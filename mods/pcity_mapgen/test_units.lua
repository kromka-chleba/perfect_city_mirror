-- Test script to verify the refactoring works

local mod_path = core.get_modpath("pcity_mapgen")

print("=== Testing new units module structure ===")

-- Test 1: Load units directly
print("\n1. Loading units.lua directly...")
local units = dofile(mod_path.."/units.lua")
print("  - units module loaded:", units ~= nil)
print("  - units.sizes exists:", units.sizes ~= nil)
print("  - units.node_to_mapchunk is function:", type(units.node_to_mapchunk) == "function")
print("  - units.sizes.node exists:", units.sizes.node ~= nil)
print("  - units.sizes.mapchunk exists:", units.sizes.mapchunk ~= nil)

-- Test 2: Test read-only sizes
print("\n2. Testing read-only sizes...")
local success, err = pcall(function()
    units.sizes.new_value = "test"
end)
print("  - Attempt to modify sizes should fail:", not success)
if not success then
    print("  - Error message:", err)
end

-- Test 3: Load sizes.lua for backward compatibility
print("\n3. Testing backward compatibility with sizes.lua...")
local sizes = dofile(mod_path.."/sizes.lua")
print("  - sizes loaded:", sizes ~= nil)
print("  - sizes.units exists:", sizes.units ~= nil)
print("  - sizes.node exists:", sizes.node ~= nil)
print("  - sizes.units.node_to_mapchunk is function:", type(sizes.units.node_to_mapchunk) == "function")

-- Test 4: Verify they point to same data
print("\n4. Verifying consistency...")
print("  - sizes.units == units:", sizes.units == units)
print("  - sizes.node == units.sizes.node:", sizes.node == units.sizes.node)

print("\n=== All tests completed ===")
