--- UPDATE THIS TO THE ACTUAL PATH!!!!
parseXmlFile = require("./vnds/lua-xmlparser/xmlparser").parseFile

vnds = {}
vnds.loading = false

defaultFunctions = {}

-- DEBUG
function tableString(t)
    a = ""
    if type(t) == "table" then
        a = a .. "{"
        first = true
        for k, v in pairs(t) do
            if not first then
                a = a .. ", "
            else
                first = false
            end
            a = a .. k .. " => " .. tableString(t[k])
        end
        a = a .. "}"
        return a
    end
    if type(t) == "string" then
        return "\"" .. t .. "\""
    end
    return tostring(t)
end

-- DEBUG END

-- init a game
-- (get all of its info to display in the selector)
function vnds.init(folder, functions)
    vnds.path = folder
    vnds.functions = functions
    vnds.vars = {}
    vnds.scripts = {}
    vnds.loading = false

    -- get the title, description and infos of the game
    file = io.open(folder .. "/info.txt", "r")
    if not file then
        print("provided folder (" .. folder .. ") is not a vnds folder")
        return
    end

    for line in file:lines() do
        eqpos = line:find("=")
        if eqpos then
            key = line:sub(1, eqpos - 1)
            value = line:sub(eqpos + 1)
            vnds[key] = value
        end
    end
    file:close()

    -- use the default functions if there is no reimplementation
    for k, v in pairs(defaultFunctions) do
        if not vnds.functions[k] then
            vnds.functions[k] = v
        end
    end
    -- TODO: load saves
    vnds.loadGlobals()
end

function vnds.load(saveSlot)
    -- TODO: load save
    if saveSlot then
        -- Load save data from file
    else
        -- Set default save data
        vnds.vars = {}
        vnds.script = "main"
        vnds.line = 1
    end

    -- check if the interpreter coroutine is running
    if vnds.interpreterRoutine then
        -- the interpeter exists.
        -- is it running?
        if coroutine.status(vnds.interpreterRoutine) == "running" or coroutine.status(vnds.interpreter) == "suspended" then
            -- stop the coroutine
            coroutine.stop(vnds.interpreterRoutine)
        end
    end

    -- load the file we will start to run
    vnds.runScript(vnds.script, vnds.line)

    -- start a new interpreter coroutine
    vnds.interpreterRoutine = coroutine.create(vnds.interpreter)
    coroutine.resume(vnds.interpreterRoutine)
end

function vnds.loadScript(script)
    print("parsing " .. script)
    if vnds.scripts[script] then
        return
    end
    vnds.loading = true
    vnds.scripts[script] = {}
    vnds.scripts[script].labels = {}
    vnds.scripts[script].lines = {}

    file = io.open(vnds.path .. "/script/" .. script .. ".scr", "r")
    if not file then
        print("provided script (" .. script .. ") is not a valid vnds script")
        return
    end

    lineNumber = 1
    recursionDepth = 0
    recursionList = {}

    for i in file:lines() do
        -- remove comments and leading/trailing whitespace
        line = i:gsub("^%s+", ""):gsub("%s+$", "")

        -- check if the line is a comment
        comment = line:find("#")

        -- check if the line has at least one word. if it does, it is a normal line
        isProperLine = line:find("^%a+")
        if line ~= "" and comment == nil and isProperLine then
            -- split the command from the rest of the line
            command, rest = line:match("^(%S+)%s*(.*)$")

            -- there is a special command that we need to take care during the parsing of the filename
            if command == "label" then
                vnds.scripts[script].labels[rest] = lineNumber
            else
                vnds.scripts[script].lines[lineNumber] = { command = command, rest = rest }
                print(lineNumber .. "\tcommand: " .. command .. "\targs: " .. rest)
                lineNumber = lineNumber + 1
            end
        end
    end
    file:close()
    vnds.loading = false
end

function vnds.runScript(script, line)
    line = line or nil

    if vnds.scripts[script] == nil then
        vnds.loadScript(script)
    end
    -- TODO: run script
    vnds.script = script
    if line then
        vnds.line = line
    else
        vnds.line = 1
    end
end

function vnds.interpreter()
    while true do
        line = vnds.scripts[vnds.script].lines[vnds.line]
        print(vnds.script .. " line " .. vnds.line)
        print(line.command)

        -- run the appropriate function if it exists
        fun = vnds.functions[line.command]
        args = vnds.parseString(line.rest)
        if fun then
            fun(args)
        else
            print("ERROR: command \"" .. line.command .. "\" is not implemented yet!")
        end

        -- go to the next line
        vnds.line = vnds.line + 1
        line = vnds.scripts[vnds.script].lines[vnds.line]
        if not line then
            vnds.runScript("main")
        end
    end
end

-- replace $-formatted vars by their actual content.
-- technically allows a variable usage to be stored in another variable, but let's be real, no one is going to do that right? right?
function vnds.parseString(s)
    while true do
        -- check if there is variable in the " $VARNAME " format
        v1, v2 = string.find(s, "%$%w+")

        -- if found, process
        if v1 and v2 then
            left = ""
            right = ""
            -- parse correctly depending on wether it's using the "new" variable format or the old one
            if string.sub(s, v1 - 1, v1 - 1) == "{" and string.sub(s, v2 + 1, v2 + 1) == "}" then
                left = string.sub(s, 1, v1 - 2)
                right = string.sub(s, v2 + 2)
            else
                left = string.sub(s, 1, v1 - 1)
                right = string.sub(s, v2 + 1, -1)
            end
            varname = string.sub(s, v1 + 1, v2)
            if vnds.vars[varname] then
                s = left .. vnds.vars[varname].value .. right
            else
                s = left .. right
            end
        else
            -- if nothing is found, return
            return s
        end
    end
end

function vnds.loadGlobals()
    globs = parseXmlFile(vnds.path .. "/save/global.sav")
    print("GLOBALS: ")
    for k, v in pairs(globs.children[1].children) do
        print("\t" .. v.attrs.name .. " = " .. v.attrs.value)
        vnds.vars[v.attrs.name] = {}
        if v.attrs.type == "int" then
            vnds.vars[v.attrs.name].value = tonumber(v.attrs.value)
        else
            vnds.vars[v.attrs.name].value = v.attrs.value
        end
        vnds.vars[v.attrs.name].global = true
    end
end

-------------------------- template reference implementation.
-- most code that does not rely on any frontend should just work
-- and should not require an override
-- this is the standard implementation, as described here:
-- https://github.com/BASLQC/vnds/blob/master/manual/script_format.txt

------------------ sensible defaults

--[[
setvar/gsetvar:
    usage: setvar modifier value
    sets a variable

    modifier: =, +. -
    setvar puts values into local save memory, to be kept in normal save files
        for things like character flags and such
    gsetvar sets variables in global.sav
        for things like cleared path flags
    prefix a variable with $ to use it in other commands: `text var is $var`
        {$var} can be used if needed to separate the variable from other text
]] --

-- define a global list of operators
vnds.operators = {}

vnds.operators["="] = function(a, b)
    return b
end

vnds.operators["+"] = function(a, b)
    if type(a) == "number" and type(b) == "number" then
        return a + b
    end
    return a .. b
end

vnds.operators["-"] = function(a, b)
    if type(a) == "number" and type(b) == "number" then
        return a - b
    end
    return a
end

function defaultFunctions.setvar(args)
    varname, operator, parameter = args:match("^(%S+)%s+(%S+)%s+(.*)$")

    -- there is this special case where we just reset the variables
    if not (varname and operator and parameter) then
        print("SYSTEM: weird formatting")
        if args == "~ ~" then
            vnds.vars = {}
            vnds.loadGlobals()
            print("SYSTEM: variables reset")
        end
        return
    end

    if string.sub(parameter, 1, 1) == "\"" and parameter:match(".$") == "\"" then
        -- the second parameter is a string
        parameter = string.sub(parameter, 2, -2)
    else
        -- check if it is a variable. if is not, convert it to a number and set it as is.
        if vnds.vars[parameter] then
            parameter = vnds.vars[parameter].value
        else
            tmp = tonumber(parameter)
            if tmp then
                parameter = tmp
            end
        end
    end

    print(varname .. operator .. parameter)
    -- now modify the variable unless it already exists and is global
    global = false
    if vnds.vars[varname] then
        global = vnds.vars[varname].global
    else
        print("ERROR: Variable '" .. varname .. "' does not exist.\nsetting it to 0")
        vnds.vars[varname] = { global = false, value = 0 }
    end
    if global then
        print(varname .. " is a global variable, let's not touch it")
    end

    if not global then
        vnds.vars[varname] = { global = false, value = vnds.operators[operator](vnds.vars[varname].value, parameter) }
        --[[
        -- simple setter
        if operator == "=" then
            vnds.vars[varname] = { global = false, value = parameter }
            print("SYSTEM: set " .. varname .. " to " .. parameter .. "(" .. type(parameter) .. ")")
        end

        -- addition of a number or string
        if operator == "+" then
            if type(vnds.vars[varname].value) == "string" then
                vnds.vars[varname].value = vnds.vars[varname].value .. parameter
                print("SYSTEM: added " .. parameter .. " to " .. varname .. "(string)")
            else
                vnds.vars[varname].value = vnds.vars[varname].value + parameter
                print("SYSTEM: added " .. parameter .. " to " .. varname .. "(number)")
            end
        end

        -- substraction of a number
        if operator == "-" and type(vnds.vars[varname].value) == "number" then
            vnds.vars[varname].value = vnds.vars[varname].value - parameter
            print("SYSTEM: substracted " .. parameter .. " from " .. varname)
        end
        ]]
    end
end

function defaultFunctions.gsetvar(args)
    varname, operator, parameter = args:match("^(%S+)%s+(%S+)%s+(.*)$")

    -- there is this special case where we just reset the variables
    if not (varname and operator and parameter) then
        print("SYSTEM: weird formatting")
        if args == "~ ~" then
            -- TODO reset global variable file
        end
        return
    end

    if string.sub(parameter, 1, 1) == "\"" and parameter:match(".$") == "\"" then
        -- the second parameter is a string
        parameter = string.sub(parameter, 2, -2)
    else
        -- check if it is a variable. if is not, convert it to a number and set it as is.
        if vnds.vars[parameter] then
            parameter = vnds.vars[parameter].value
        else
            tmp = tonumber(parameter)
            if tmp then
                parameter = tmp
            end
        end
    end

    print(varname .. operator .. parameter .. "\t(G)")
    -- now modify the variable unless it already exists and is global
    global = true
    if vnds.vars[varname] then
        global = vnds.vars[varname].global
    else
        print("ERROR: Variable '" .. varname .. "' does not exist.\nsetting it to 0")
        vnds.vars[varname] = { global = true, value = 0 }
    end
    if not global then
        print(varname .. " is not a global variable, let's not touch it")
    end

    if global then
        vnds.vars[varname] = {
            global = true,
            value = vnds.operators[operator](vnds.vars[varname].value, parameter)
        }
    end

    -- TODO: save global variables
    f = io.open(vnds.path .. "/save/global.sav", "w")
    f:write("<global>\n")
    for k, _ in pairs(vnds.vars) do
        print(k .. " => " .. tableString(vnds.vars[k]))
        if vnds.vars[k].global then
            print("b")
            vartype = "int"
            if type(vnds.vars[k].value) == "string" then
                vartype = "str"
            end
            f:write("  <var name=\"" .. k .. "\" type=\"" .. vartype .. "\" value=\"" .. vnds.vars[k].value .. "\" />\n")
        end
    end
    f:write("</global>\n")
    f:close()
end

--[[
if/fi:
    usage:
        if x == 1
            commands
        fi
    conditional jump

    if true, it keeps reading. if false, it skips till it encounters a fi
    Note: left operand must be a variable, right may be either
        This is due to either redoing every script to put $ in front of the
            variables, or just making left not default to string if the
            variable doesnt exist.
]]

-- add comparison operators to the list
vnds.operators["=="] = function(a, b)
    return a == b
end
vnds.operators["!="] = function(a, b)
    return a ~= b
end
vnds.operators["<"] = function(a, b)
    return a < b
end
vnds.operators[">"] = function(a, b)
    return a > b
end
vnds.operators["<="] = function(a, b)
    return a <= b
end
vnds.operators[">="] = function(a, b)
    return a >= b
end
function defaultFunctions._if(args)
    left, operator, right = args:match("^(%S+)%s+(%S+)%s+(%S+)$")
    -- left is always a variable
    left = vnds.vars[left].value

    -- right can be either a string, a number or a variable
    if string.sub(right, 1, 1) == "\"" and string.sub(right, -1, -1) then
        -- this is a string
        right = right:sub(2, -2)
        print(right)
    else
        tmp = tonumber(right)
        if tmp then
            right = tmp
        else
            right = vnds.vars[right].value
        end
    end
    -- check the truthfulness of the expression
    if not vnds.operators[operator](left, right) then
        -- run through the lines until we find a fi. with depth
        depth = 1
        while true do
            vnds.line = vnds.line + 1
            if vnds.scripts[vnds.script].lines[vnds.line].command == "if" then
                depth = depth + 1
            end
            if vnds.scripts[vnds.script].lines[vnds.line].command == "fi" then
                depth = depth - 1
                if depth == 0 then
                    return
                end
            end
        end
    end
end

defaultFunctions["if"] = defaultFunctions._if

function defaultFunctions.fi(args)
    return
end

--[[
jump:
    usage: jump file.scr [label]
    looks in script/ for the .scr and starts reading off that.
    if label is specified, jumps to that label in the script
]]
function defaultFunctions.jump(args)
    script, label = args:match("^(%S+)%s*(.*)$")
    script = script:match("^(%a+)")
    vnds.loadScript(script)
    if label then
        vnds.runScript(script, vnds.scripts[script].labels[label])
    else
        vnds.runScript(script)
    end
    vnds.line = vnds.line - 1
end

--[[
random:
    usage: random var low high
    set var to a number between low and high (inclusive)
]]
function defaultFunctions.random(args)
end

--[[
label/goto:
    usage:
        label name
        goto name

    a goto command will search the current script for a label with the same
        name and start the script from that part
]]
function defaultFunctions._goto(args)
    vnds.runScript(vnds.script, vnds.scripts[vnds.script].labels[args])
end

defaultFunctions["goto"] = defaultFunctions._goto

-- note that unlike fi, there cannot be any labels,
-- they are stripped during the initial parsing of the script



------------------ please override

--[[
bgload:
    usage: bgload file [fadetime]
    looks in background/ for the image and draws it as the background
    control length of fade in frames with fadetime (default 16)
]]
function defaultFunctions.bgload(args)
end

--[[
setimg:
    usage: setimg file x y
    looks in foreground/ for the image and draws it at the point (x,y)
]]
function defaultFunctions.setimg(args)
end

--[[
sound:
    usage: sound file times
    looks in sound/ for the file, loads it into memory(don`t do this with
        anything over a meg in size) and plays it X times. -1 for infinite
        looping.
    if file is ~, it stops any currently playing sound.
]]
function defaultFunctions.sound(args)
end

--[[
music:
    usage: music file
    looks in sound/ for the file,

    music is expected to be in mp3 format
    if file is ~, it stops the music.
]]
function defaultFunctions.music(args)
end

--[[
text:
    usage: text string
    displays text to the screen.

    Prepending string with @ makes it not require clicking to advance
    if string is ~, it`ll make a blank line
    if string is !, it`ll make a blank line and require clicking to advance
]]
function defaultFunctions.text(args)
end

--[[
choice:
    usage: choice option1|option2|etc...
    displays choices on the screen

    when a choice is clicked, selected is set to the value of what was
        selected, starting at 1.
    use if selected == 1, etc to go off what was selected.
]]
function defaultFunctions.choice(args)
end

--[[
delay:
    usage: delay X
    X being number of frames to hold, DS runs at 60 frames per second.

(note: considering that depending on the frontend implementation,
just waiting could make the whole game unresponsive,
i decided to leave it to the front-end implementation)
]]
function defaultFunctions.delay(args)
end

--[[
cleartext:
    usage: cleartext [type]
    clears text from the screen.

    if no type is given, it`ll make enough blank lines to fill the display
    if type is !, it`ll completely clear the text buffer (including history)
(note: leave that one for the end, it can be tricky to implement, and is barely used in any games)
]]
function defaultFunctions.cleartext(args)
end

return vnds
--[[
Notes:
    titlescreen:
        icon: 32x32 .png
        thumbnail 100x75 .png

    To place a variable in a command, prefix the variable name with $ and it
        will directly replace it. Strings only
    (notes concerning this implementation about the last sentence:
    just do whatever the fuck you want here, the whole part after the command will be interpreted.
    meaning you can have a variable $something containting "x == 10" and do an if $something and it will just work.
    this is dumb, but it allows me to optimize the number of lines so whatever)

Conversion:
    Images:
        Sprites should be in png format and backgrounds as jpg or png. Alpha
            transparency is supported for sprites.
        To avoid color banding, decrease the color depth of the images to
            5bits/channel and use dithering (png doesn't support 5bits/channel,
			so store them in 8bits/channel instead).
        For background images you should also make sure that they're 256x192
            in size.

    Sound:
        Sound effects should be encoded in aac.

        `ffmpeg -i infile -acodec libfaac outfile`

	.zip:
        For increased file access performance, put the files in an uncompressed
        .zip file. each folder should get its own archive: background.zip,
        foreground.zip, script.zip, sound.zip.
]]
