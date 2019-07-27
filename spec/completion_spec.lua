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
    opts="-h --help --completion -v --verbose -f --files"

    case "$prev" in
        --completion)
            COMPREPLY=($(compgen -W "bash zsh fish" -- "$cur"))
            return 0
            ;;
        -f|--files)
            COMPREPLY=($(compgen -f "$cur"))
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
            esac

            opts="$opts -h --help --deps-mode --no-doc"
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
#compdef comptest

_comptest() {
  local context state state_descr line
  typeset -A opt_args

  local -a options=(
    {-h,--help}"[Show this help message and exit]"
    "--completion[Output a shell completion script for the specified shell]: :(bash zsh fish)"
    "*"{-v,--verbose}"[Set the verbosity level]"
    {-f,--files}"[A description with illegal \"' characters]:*: :_files"
  )
  _arguments -s -S \
    $options \
    ": :_comptest_cmds" \
    "*:: :->args" \
    && return 0

  case $words[1] in
    help)
      options=(
        $options
        {-h,--help}"[Show this help message and exit]"
      )
      _arguments -s -S \
        $options \
        ": :(help completion install i admin)" \
        && return 0
      ;;

    completion)
      options=(
        $options
        {-h,--help}"[Show this help message and exit]"
      )
      _arguments -s -S \
        $options \
        ": :(bash zsh fish)" \
        && return 0
      ;;

    install|i)
      options=(
        $options
        {-h,--help}"[Show this help message and exit]"
        "--deps-mode: :(all one order none)"
        "--no-doc[Install without documentation]"
      )
      _arguments -s -S \
        $options \
        && return 0
      ;;

    admin)
      options=(
        $options
        {-h,--help}"[Show this help message and exit]"
      )
      _arguments -s -S \
        $options \
        ": :_comptest_admin_cmds" \
        "*:: :->args" \
        && return 0

      case $words[1] in
        help)
          options=(
            $options
            {-h,--help}"[Show this help message and exit]"
          )
          _arguments -s -S \
            $options \
            ": :(help add remove)" \
            && return 0
          ;;

        add)
          options=(
            $options
            {-h,--help}"[Show this help message and exit]"
          )
          _arguments -s -S \
            $options \
            ": :_files" \
            && return 0
          ;;

        remove)
          options=(
            $options
            {-h,--help}"[Show this help message and exit]"
          )
          _arguments -s -S \
            $options \
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
    "admin:Rock server administration interface"
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

_comptest
]=], get_output("completion zsh"))
   end)

   it("generates correct fish completion script", function()
      assert.equal([=[

complete -c comptest -n '__fish_use_subcommand' -xa 'help' -d 'Show help for commands'
complete -c comptest -n '__fish_use_subcommand' -xa 'completion' -d 'Output a shell completion script'
complete -c comptest -n '__fish_use_subcommand' -xa 'install' -d 'Install a rock'
complete -c comptest -n '__fish_use_subcommand' -xa 'i' -d 'Install a rock'
complete -c comptest -n '__fish_use_subcommand' -xa 'admin' -d 'Rock server administration interface'
complete -c comptest -s h -l help -d 'Show this help message and exit'
complete -c comptest -l completion -xa 'bash zsh fish' -d 'Output a shell completion script for the specified shell'
complete -c comptest -s v -l verbose -d 'Set the verbosity level'
complete -c comptest -s f -l files -r -d 'A description with illegal "\' characters'

complete -c comptest -n '__fish_seen_subcommand_from help' -xa 'help completion install i admin'
complete -c comptest -n '__fish_seen_subcommand_from help' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_seen_subcommand_from completion' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_seen_subcommand_from install i' -s h -l help -d 'Show this help message and exit'
complete -c comptest -n '__fish_seen_subcommand_from install i' -l deps-mode -xa 'all one order none'
complete -c comptest -n '__fish_seen_subcommand_from install i' -l no-doc -d 'Install without documentation'

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
