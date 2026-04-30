const fs = require("fs")
const luamin = require('lua-format')

const Code = fs.readFileSync(process.argv[2],"utf-8")
const Settings = {
  RenameVariables: true,
  RenameGlobals: false,
  SolveMath: true,
  Indentation: '\t'
}

const Beautified = luamin.Beautify(Code, Settings)
const Minified = luamin.Minify(Code, Settings)
fs.writeFileSync(process.argv[2],"utf-8")
