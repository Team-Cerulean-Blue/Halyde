local args = {...}

print(user.addTask(function()
  print("I eat rocks")
  print(tsched.getCurrentTask())
end, "testerpester", tonumber(args[1]), args[2]))
