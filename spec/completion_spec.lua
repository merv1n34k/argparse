local script = "./spec/comptest"
local script_cmd = "lua"

if package.loaded["luacov.runner"] then
   script_cmd = script_cmd .. " -lluacov"
end

script_cmd = script_cmd .. " " .. script

local function get_output(args)
   local handler = io.popen(script_cmd .. " " .. args .. " 2>&1", "r")
   local output = handler:read("*a")
   handler:close()
   return output
end

describe("tests related to generation of shell completion scripts", function()
   it("generates correct bash completion script", function()
      assert.equal([=[
_comptest() {
    local IFS=$' \t\n'
    local cur prev cmd opts arg
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="comptest"
    opts="-h --help -f --files --direction"

    case "$prev" in
        -f|--files)
            COMPREPLY=($(compgen -f "$cur"))
            return 0
            ;;
        --direction)
            COMPREPLY=($(compgen -W "north south east west" -- "$cur"))
            return 0
            ;;
    esac

    for arg in ${COMP_WORDS[@]:1}; do
        case "$arg" in
            completion)
                cmd="completion"
                break
                ;;
            install|i)
                cmd="install"
                break
                ;;
            admin)
                cmd="admin"
                break
                ;;
        esac
    done

    case "$cmd" in
        comptest)
            COMPREPLY=($(compgen -W "help completion install i admin" -- "$cur"))
            ;;
        completion)
            opts="$opts -h --help"
            ;;
        install)
            case "$prev" in
                --deps-mode)
                    COMPREPLY=($(compgen -W "all one order none" -- "$cur"))
                    return 0
                    ;;
                --pair)
                    COMPREPLY=($(compgen -f "$cur"))
                    return 0
                    ;;
            esac

            opts="$opts -h --help --deps-mode --no-doc --pair"
            ;;
        admin)
            opts="$opts -h --help"
            ;;
    esac

    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _comptest -o bashdefault -o default comptest
]=], get_output("completion bash"))
   end)

   it("generates correct zsh completion script", function()
      assert.equal([=[
compdef _comptest comptest

_comptest() {
  local context state state_descr line
  typeset -A opt_args

  _arguments -s -S \
    {-h,--help}"[Show this help message and exit]" \
    {-f,--files}"[A description with illegal \' characters]:*: :_files" \
    "--direction[The direction to go in]: :(north south east west)" \
    ": :_comptest_cmds" \
    "*:: :->args" \
    && return 0

  case $words[1] in
    help)
      _arguments -s -S \
        {-h,--help}"[Show this help message and exit]" \
        ": :(help completion install i admin)" \
        && return 0
      ;;

    completion)
      _arguments -s -S \
        {-h,--help}"[Show this help message and exit]" \
        ": :(bash zsh fish)" \
        && return 0
      ;;

    install|i)
      _arguments -s -S \
        {-h,--help}"[Show this help message and exit]" \
        "--deps-mode: :(all one order none)" \
        "--no-doc[Install without documentation]" \
        "*--pair[A pair of files]: :_files" \
        && return 0
      ;;

    admin)
      _arguments -s -S \
        {-h,--help}"[Show this help message and exit]" \
        ": :_comptest_admin_cmds" \
        "*:: :->args" \
        && return 0

      case $words[1] in
        help)
          _arguments -s -S \
            {-h,--help}"[Show this help message and exit]" \
            ": :(help add remove)" \
            && return 0
          ;;

        add)
          _arguments -s -S \
            {-h,--help}"[Show this help message and exit]" \
            ": :_files" \
            && return 0
          ;;

        remove)
          _arguments -s -S \
            {-h,--help}"[Show this help message and exit]" \
            ": :_files" \
            && return 0
          ;;

      esac
      ;;

  esac

  return 1
}

_comptest_cmds() {
  local -a commands=(
    "help:Show help for commands"
    "completion:Output a shell completion script"
    {install,i}":Install a rock"
    "admin"
  )
  _describe "command" commands
}

_comptest_admin_cmds() {
  local -a commands=(
    "help:Show help for commands"
    "add:Add a rock to a server"
    "remove:Remove a rock from  a server"
  )
  _describe "command" commands
}
]=], get_output("completion zsh"))
   end)

   it("generates correct fish completion script", function()
      assert.equal([=[

complete -c comptest -n '__fish_use_subcommand' -xa 'help' -d 'Show help for commands'
complete -c comptest -n '__fish_use_subcommand' -xa 'completion' -d 'Output a shell completion script'
complete -c comptest -n '__fish_use_subcommand' -xa 'install' -d 'Install a rock'
complete -c comptest -n '__fish_use_subcommand' -xa 'i' -d 'Install a rock'
complete -c comptest -n '__fish_use_subcommand' -xa 'admin'
complete -c comptest -s h -l help -d 'Show this help message and exit'
complete -c comptest -s f -l files -r -d 'A description with illegal \\\' characters'
complete -c comptest -l direction -xa 'north south east west' -d 'The direction to go in'

complete -c comptest -n '__fish_seen_subcommand_from help' -xa 'help completion install i admin'
complete -c comptest -n '__fish_seen_subcommand_from help' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_seen_subcommand_from completion' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_seen_subcommand_from install i' -s h -l help -d 'Show this help message and exit'
complete -c comptest -n '__fish_seen_subcommand_from install i' -l deps-mode -xa 'all one order none'
complete -c comptest -n '__fish_seen_subcommand_from install i' -l no-doc -d 'Install without documentation'
complete -c comptest -n '__fish_seen_subcommand_from install i' -l pair -r -d 'A pair of files'

complete -c comptest -n '__fish_use_subcommand' -xa 'help' -d 'Show help for commands'
complete -c comptest -n '__fish_use_subcommand' -xa 'add' -d 'Add a rock to a server'
complete -c comptest -n '__fish_use_subcommand' -xa 'remove' -d 'Remove a rock from  a server'
complete -c comptest -n '__fish_seen_subcommand_from admin' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_seen_subcommand_from help' -xa 'help add remove'
complete -c comptest -n '__fish_seen_subcommand_from help' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_seen_subcommand_from add' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_seen_subcommand_from remove' -s h -l help -d 'Show this help message and exit'
]=], get_output("completion fish"))
   end)
end)
