-- TODO: Rename this to something else (while making an alias from the original command).
-- Touch seems kind of a silly name for a command to make a file.
-- Maybe something like mkfile would be better?
local cliparse = require("cliparse")
cliparse.config({
  ["o"] = 0,
  ["overwrite"] = 0,
})
local parsed = cliparse.parse(...)
local file = parsed.args[1]
local fs = require("filesystem")
local shell = require("shell")

if not file then
  return shell.run("help touch")
end

if file:sub(1, 1) ~= "/" then
  file = fs.concat(shell.getWorkingDirectory(), file)
end

if fs.exists(file) and not (parsed.flags.o or parsed.flags.overwrite) then
  return print("\x1b[91mFile already exists.\n│  To empty file contents, use -o.")
end

local handle = fs.open(file, "w")
handle:write("") -- just in case
handle:close()
