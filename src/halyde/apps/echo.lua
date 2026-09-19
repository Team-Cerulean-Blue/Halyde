local args = {...}
local concatText = args[1]
table.remove(args, 1)
for _, item in pairs(args) do
  concatText = concatText .. " " .. item
end
print(concatText)
