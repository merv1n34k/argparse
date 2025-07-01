local function base_name(pathname)
    return pathname:gsub("[/\\]*$", ""):match(".*[/\\]([^/\\]*)") or pathname
end

local function get_short_description(element)
    local short = element:_get_description():match("^(.-)%.%s")
    return short or element:_get_description():match("^(.-)%.?$")
end

-----------------------------
--- Parser main functions ---
-----------------------------

function Parser:_is_shell_safe()
    if self._basename then
        if self._basename:find("[^%w_%-%+%.]") then
            return false
        end
    else
        for _, alias in ipairs(self._aliases) do
            if alias:find("[^%w_%-%+%.]") then
                return false
            end
        end
    end
    for _, option in ipairs(self._options) do
        for _, alias in ipairs(option._aliases) do
            if alias:find("[^%w_%-%+%.]") then
                return false
            end
        end
        if option._choices then
            for _, choice in ipairs(option._choices) do
                if choice:find("[%s'\"]") then
                    return false
                end
            end
        end
    end
    for _, argument in ipairs(self._arguments) do
        if argument._choices then
            for _, choice in ipairs(argument._choices) do
                if choice:find("[%s'\"]") then
                    return false
                end
            end
        end
    end
    for _, command in ipairs(self._commands) do
        if not command:_is_shell_safe() then
            return false
        end
    end
    return true
end

function Parser:add_complete(value)
    if value then
        assert(
            type(value) == "string" or type(value) == "table",
            ("bad argument #1 to 'add_complete' (string or table expected, got %s)"):format(type(value))
        )
    end

    local complete = self:option()
        :description("Output a shell completion script for the specified shell.")
        :args(1)
        :choices({ "bash", "zsh", "fish" })
        :action(function(_, _, shell)
            io.write(self["get_" .. shell .. "_complete"](self))
            os.exit(0)
        end)

    if value then
        complete = complete(value)
    end

    if not complete._name then
        complete("--completion")
    end

    return self
end

function Parser:add_complete_command(value)
    if value then
        assert(
            type(value) == "string" or type(value) == "table",
            ("bad argument #1 to 'add_complete_command' (string or table expected, got %s)"):format(type(value))
        )
    end

    local complete = self:command():description("Output a shell completion script.")
    complete
        :argument("shell")
        :description("The shell to output a completion script for.")
        :choices({ "bash", "zsh", "fish" })
        :action(function(_, _, shell)
            io.write(self["get_" .. shell .. "_complete"](self))
            os.exit(0)
        end)

    if value then
        complete = complete(value)
    end

    if not complete._name then
        complete("completion")
    end

    return self
end

function Parser:_bash_option_args(buf, indent)
    local opts = {}
    for _, option in ipairs(self._options) do
        if option._choices or option._minargs > 0 then
            local compreply
            if option._choices then
                compreply = 'COMPREPLY=($(compgen -W "' .. table.concat(option._choices, " ") .. '" -- "$cur"))'
            else
                compreply = 'COMPREPLY=($(compgen -f -- "$cur"))'
            end
            table.insert(opts, (" "):rep(indent + 4) .. table.concat(option._aliases, "|") .. ")")
            table.insert(opts, (" "):rep(indent + 8) .. compreply)
            table.insert(opts, (" "):rep(indent + 8) .. "return 0")
            table.insert(opts, (" "):rep(indent + 8) .. ";;")
        end
    end

    if #opts > 0 then
        table.insert(buf, (" "):rep(indent) .. 'case "$prev" in')
        table.insert(buf, table.concat(opts, "\n"))
        table.insert(buf, (" "):rep(indent) .. "esac\n")
    end
end

function Parser:_bash_get_cmd(buf, indent)
    if #self._commands == 0 then
        return
    end

    table.insert(buf, (" "):rep(indent) .. 'args=("${args[@]:1}")')
    table.insert(buf, (" "):rep(indent) .. 'for arg in "${args[@]}"; do')
    table.insert(buf, (" "):rep(indent + 4) .. 'case "$arg" in')

    for _, command in ipairs(self._commands) do
        table.insert(buf, (" "):rep(indent + 8) .. table.concat(command._aliases, "|") .. ")")
        if self._parent then
            table.insert(buf, (" "):rep(indent + 12) .. 'cmd="$cmd ' .. command._name .. '"')
        else
            table.insert(buf, (" "):rep(indent + 12) .. 'cmd="' .. command._name .. '"')
        end
        table.insert(buf, (" "):rep(indent + 12) .. 'opts="$opts ' .. command:_get_options() .. '"')
        command:_bash_get_cmd(buf, indent + 12)
        table.insert(buf, (" "):rep(indent + 12) .. "break")
        table.insert(buf, (" "):rep(indent + 12) .. ";;")
    end

    table.insert(buf, (" "):rep(indent + 4) .. "esac")
    table.insert(buf, (" "):rep(indent) .. "done")
end

function Parser:_bash_cmd_completions(buf)
    local cmd_buf = {}
    if self._parent then
        self:_bash_option_args(cmd_buf, 12)
    end
    if #self._commands > 0 then
        table.insert(cmd_buf, (" "):rep(12) .. 'COMPREPLY=($(compgen -W "' .. self:_get_commands() .. '" -- "$cur"))')
    elseif self._is_help_command then
        table.insert(
            cmd_buf,
            (" "):rep(12) .. 'COMPREPLY=($(compgen -W "' .. self._parent:_get_commands() .. '" -- "$cur"))'
        )
    end
    if #cmd_buf > 0 then
        table.insert(buf, (" "):rep(8) .. "'" .. self:_get_fullname(true) .. "')")
        table.insert(buf, table.concat(cmd_buf, "\n"))
        table.insert(buf, (" "):rep(12) .. ";;")
    end

    for _, command in ipairs(self._commands) do
        command:_bash_cmd_completions(buf)
    end
end

function Parser:get_bash_complete()
    self._basename = base_name(self._name)
    assert(self:_is_shell_safe())
    local buf = {
        ([[
_%s() {
    local IFS=$' \t\n'
    local args cur prev cmd opts arg
    args=("${COMP_WORDS[@]}")
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="%s"
]]):format(self._basename, self:_get_options()),
    }

    self:_bash_option_args(buf, 4)
    self:_bash_get_cmd(buf, 4)
    if #self._commands > 0 then
        table.insert(buf, "")
        table.insert(buf, (" "):rep(4) .. 'case "$cmd" in')
        self:_bash_cmd_completions(buf)
        table.insert(buf, (" "):rep(4) .. "esac\n")
    end

    table.insert(
        buf,
        ([=[
    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _%s -o bashdefault -o default %s
]=]):format(self._basename, self._basename)
    )

    return table.concat(buf, "\n")
end

function Parser:_zsh_arguments(buf, cmd_name, indent)
    if self._parent then
        table.insert(buf, (" "):rep(indent) .. "options=(")
        table.insert(buf, (" "):rep(indent + 2) .. "$options")
    else
        table.insert(buf, (" "):rep(indent) .. "local -a options=(")
    end

    for _, option in ipairs(self._options) do
        local line = {}
        if #option._aliases > 1 then
            if option._maxcount > 1 then
                table.insert(line, '"*"')
            end
            table.insert(line, "{" .. table.concat(option._aliases, ",") .. '}"')
        else
            table.insert(line, '"')
            if option._maxcount > 1 then
                table.insert(line, "*")
            end
            table.insert(line, option._name)
        end
        if option._description then
            local description = get_short_description(option):gsub('["%]:`$]', "\\%0")
            table.insert(line, "[" .. description .. "]")
        end
        if option._maxargs == math.huge then
            table.insert(line, ":*")
        end
        if option._choices then
            table.insert(line, ": :(" .. table.concat(option._choices, " ") .. ")")
        elseif option._maxargs > 0 then
            table.insert(line, ": :_files")
        end
        table.insert(line, '"')
        table.insert(buf, (" "):rep(indent + 2) .. table.concat(line))
    end

    table.insert(buf, (" "):rep(indent) .. ")")
    table.insert(buf, (" "):rep(indent) .. "_arguments -s -S \\")
    table.insert(buf, (" "):rep(indent + 2) .. "$options \\")

    if self._is_help_command then
        table.insert(buf, (" "):rep(indent + 2) .. '": :(' .. self._parent:_get_commands() .. ')" \\')
    else
        for _, argument in ipairs(self._arguments) do
            local spec
            if argument._choices then
                spec = ": :(" .. table.concat(argument._choices, " ") .. ")"
            else
                spec = ": :_files"
            end
            if argument._maxargs == math.huge then
                table.insert(buf, (" "):rep(indent + 2) .. '"*' .. spec .. '" \\')
                break
            end
            for _ = 1, argument._maxargs do
                table.insert(buf, (" "):rep(indent + 2) .. '"' .. spec .. '" \\')
            end
        end

        if #self._commands > 0 then
            table.insert(buf, (" "):rep(indent + 2) .. '": :_' .. cmd_name .. '_cmds" \\')
            table.insert(buf, (" "):rep(indent + 2) .. '"*:: :->args" \\')
        end
    end

    table.insert(buf, (" "):rep(indent + 2) .. "&& return 0")
end

function Parser:_zsh_cmds(buf, cmd_name)
    table.insert(buf, "\n_" .. cmd_name .. "_cmds() {")
    table.insert(buf, "  local -a commands=(")

    for _, command in ipairs(self._commands) do
        local line = {}
        if #command._aliases > 1 then
            table.insert(line, "{" .. table.concat(command._aliases, ",") .. '}"')
        else
            table.insert(line, '"' .. command._name)
        end
        if command._description then
            table.insert(line, ":" .. get_short_description(command):gsub('["`$]', "\\%0"))
        end
        table.insert(buf, "    " .. table.concat(line) .. '"')
    end

    table.insert(buf, '  )\n  _describe "command" commands\n}')
end

function Parser:_zsh_complete_help(buf, cmds_buf, cmd_name, indent)
    if #self._commands == 0 then
        return
    end

    self:_zsh_cmds(cmds_buf, cmd_name)
    table.insert(buf, "\n" .. (" "):rep(indent) .. "case $words[1] in")

    for _, command in ipairs(self._commands) do
        local name = cmd_name .. "_" .. command._name
        table.insert(buf, (" "):rep(indent + 2) .. table.concat(command._aliases, "|") .. ")")
        command:_zsh_arguments(buf, name, indent + 4)
        command:_zsh_complete_help(buf, cmds_buf, name, indent + 4)
        table.insert(buf, (" "):rep(indent + 4) .. ";;\n")
    end

    table.insert(buf, (" "):rep(indent) .. "esac")
end

function Parser:get_zsh_complete()
    self._basename = base_name(self._name)
    assert(self:_is_shell_safe())
    local buf = { ("#compdef %s\n"):format(self._basename) }
    local cmds_buf = {}
    table.insert(buf, "_" .. self._basename .. "() {")
    if #self._commands > 0 then
        table.insert(buf, "  local context state state_descr line")
        table.insert(buf, "  typeset -A opt_args\n")
    end
    self:_zsh_arguments(buf, self._basename, 2)
    self:_zsh_complete_help(buf, cmds_buf, self._basename, 2)
    table.insert(buf, "\n  return 1")
    table.insert(buf, "}")

    local result = table.concat(buf, "\n")
    if #cmds_buf > 0 then
        result = result .. "\n" .. table.concat(cmds_buf, "\n")
    end
    return result .. "\n\n_" .. self._basename .. "\n"
end

local function fish_escape(string)
    return string:gsub("[\\']", "\\%0")
end

function Parser:_fish_get_cmd(buf, indent)
    if #self._commands == 0 then
        return
    end

    table.insert(buf, (" "):rep(indent) .. "set -e cmdline[1]")
    table.insert(buf, (" "):rep(indent) .. "for arg in $cmdline")
    table.insert(buf, (" "):rep(indent + 4) .. "switch $arg")

    for _, command in ipairs(self._commands) do
        table.insert(buf, (" "):rep(indent + 8) .. "case " .. table.concat(command._aliases, " "))
        table.insert(buf, (" "):rep(indent + 12) .. "set cmd $cmd " .. command._name)
        command:_fish_get_cmd(buf, indent + 12)
        table.insert(buf, (" "):rep(indent + 12) .. "break")
    end

    table.insert(buf, (" "):rep(indent + 4) .. "end")
    table.insert(buf, (" "):rep(indent) .. "end")
end

function Parser:_fish_complete_help(buf, basename)
    local prefix = "complete -c " .. basename
    table.insert(buf, "")

    for _, command in ipairs(self._commands) do
        local aliases = table.concat(command._aliases, " ")
        local line
        if self._parent then
            line = ("%s -n '__fish_%s_using_command %s' -xa '%s'"):format(
                prefix,
                basename,
                self:_get_fullname(true),
                aliases
            )
        else
            line = ("%s -n '__fish_%s_using_command' -xa '%s'"):format(prefix, basename, aliases)
        end
        if command._description then
            line = ("%s -d '%s'"):format(line, fish_escape(get_short_description(command)))
        end
        table.insert(buf, line)
    end

    if self._is_help_command then
        local line = ("%s -n '__fish_%s_using_command %s' -xa '%s'"):format(
            prefix,
            basename,
            self:_get_fullname(true),
            self._parent:_get_commands()
        )
        table.insert(buf, line)
    end

    for _, option in ipairs(self._options) do
        local parts = { prefix }

        if self._parent then
            table.insert(parts, "-n '__fish_" .. basename .. "_seen_command " .. self:_get_fullname(true) .. "'")
        end

        for _, alias in ipairs(option._aliases) do
            if alias:match("^%-.$") then
                table.insert(parts, "-s " .. alias:sub(2))
            elseif alias:match("^%-%-.+") then
                table.insert(parts, "-l " .. alias:sub(3))
            end
        end

        if option._choices then
            table.insert(parts, "-xa '" .. table.concat(option._choices, " ") .. "'")
        elseif option._minargs > 0 then
            table.insert(parts, "-r")
        end

        if option._description then
            table.insert(parts, "-d '" .. fish_escape(get_short_description(option)) .. "'")
        end

        table.insert(buf, table.concat(parts, " "))
    end

    for _, command in ipairs(self._commands) do
        command:_fish_complete_help(buf, basename)
    end
end

function Parser:get_fish_complete()
    self._basename = base_name(self._name)
    assert(self:_is_shell_safe())
    local buf = {}

    if #self._commands > 0 then
        table.insert(
            buf,
            ([[
function __fish_%s_print_command
    set -l cmdline (commandline -poc)
    set -l cmd]]):format(self._basename)
        )
        self:_fish_get_cmd(buf, 4)
        table.insert(
            buf,
            ([[
    echo "$cmd"
end

function __fish_%s_using_command
    test (__fish_%s_print_command) = "$argv"
    and return 0
    or return 1
end

function __fish_%s_seen_command
    string match -q "$argv*" (__fish_%s_print_command)
    and return 0
    or return 1
end]]):format(self._basename, self._basename, self._basename, self._basename)
        )
    end

    self:_fish_complete_help(buf, self._basename)
    return table.concat(buf, "\n") .. "\n"
end
