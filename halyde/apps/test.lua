for i = 1, 100 do
   profiler.start("math_work")
   local x = 0
   for j = 1, 200000 do x = x + math.sqrt(j) end
   profiler.stop("math_work")

   profiler.start("string_work")
   local s = ""
   for j = 1, 2000 do s = s .. tostring(j) end
   profiler.stop("string_work")
 end

for _, r in ipairs(profiler.results()) do
  print(r.label, r.time)
end
