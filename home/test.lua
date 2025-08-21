local pid = tsched.getCurrentTask().id
local shareTable = ipc.shareWith(pid)
shareTable.gabbagool = "Pigeon Pizza! Wow!"
print(shareTable.gabbagool)
print(pid)
print(ipc.shared[pid].gabbagool)
