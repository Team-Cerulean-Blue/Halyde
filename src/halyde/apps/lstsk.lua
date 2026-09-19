local tasks = tsched.getTasks()
print("\27[93m"..tostring(#tasks).."\27[0m tasks active")
for i=1, #tasks do
    local pipeChar = "├ "
    if i==#tasks then pipeChar = "└ " end
    local task = tasks[i]
    print("\27[93m"..pipeChar..(task.id or i).."\27[0m - "..task.name.."\27[37m "..table.concat(task.args or {}," ").." \27[0m")
end
