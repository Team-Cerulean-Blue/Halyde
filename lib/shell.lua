local filesystem = require("filesystem")

-- get a list of installed shells
local shellDir = filesystem.list("/halyde/shell/")
local shells = {}
for i=1,#shellDir do
  table.insert(shells,string.match(shellDir[i],"([^/]+)%.lua$"))
end

-- locate the shell
local tasks = tsched.getTasks()
-- print(tasks)
local pid = tsched.getCurrentTask().id
local function taskFromPID(pid)
  checkArg(1,pid,"number")
  for i=1,#tasks do
    if tasks[i] and tasks[i].id==pid then
      return tasks[i]
    end
  end
end
local shellProcess
while true do
  local task = taskFromPID(pid)
  if not task then
    error("parent shell task doesn't exist (ID="..pid..")")
  end
  if table.find(shells,task.name) then
    shellProcess = task
    break
  end
  pid = task.parent
  if not pid then
    error("could not find parent shell task")
  end
end
if not shellProcess then error("could not locate shell task") end

-- get the shell object from the process
-- print("Process ID: "..shellProcess.id)
-- print(ipc.shared[shellProcess.id].shell)
return ipc.shared[shellProcess.id].shell
