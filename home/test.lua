local cor = coroutine.create(function()
  print("Hello World!")
end)

print(coroutine.status(cor))
coroutine.resume(cor)
print(coroutine.status(cor))
