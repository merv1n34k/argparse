local Parser = require "argparse"
getmetatable(Parser()).error = function(_, msg) error(msg) end

describe("tests related to generation of shell completion scripts", function()
   describe("bash completion scripts", function()
      it("generates correct completions for help flag", function()
         local parser = Parser "foo"
         assert.equal([=[
_foo() {
    local cur prev cmd opts arg
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="foo"
    opts="-h --help"

    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _foo -o bashdefault -o default foo
]=], parser:get_bash_complete())
      end)

      it("generates correct completions for options with required argument", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:option "--bar"
         assert.equal([=[
_foo() {
    local cur prev cmd opts arg
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="foo"
    opts="--bar"

    case "$prev" in
        --bar)
            COMPREPLY=($(compgen -f "$cur"))
            return 0
            ;;
    esac

    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _foo -o bashdefault -o default foo
]=], parser:get_bash_complete())
      end)

      it("generates correct completions for options with argument choices", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:option "--format"
            :choices {"short", "medium", "full"}
         assert.equal([=[
_foo() {
    local cur prev cmd opts arg
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="foo"
    opts="--format"

    case "$prev" in
        --format)
            COMPREPLY=($(compgen -W "short medium full" -- "$cur"))
            return 0
            ;;
    esac

    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _foo -o bashdefault -o default foo
]=], parser:get_bash_complete())
      end)

      it("generates correct completions for commands", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:command "install"
            :add_help(false)
         assert.equal([=[
_foo() {
    local cur prev cmd opts arg
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="foo"
    opts=""

    for arg in ${COMP_WORDS[@]:1}; do
        case "$arg" in
            install)
                cmd="install"
                break
                ;;
        esac
    done

    case "$cmd" in
        foo)
            COMPREPLY=($(compgen -W "install" -- "$cur"))
            ;;
    esac

    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _foo -o bashdefault -o default foo
]=], parser:get_bash_complete())
      end)

      it("generates correct completions for command options", function()
         local parser = Parser "foo"
            :add_help(false)
         local install = parser:command "install"
            :add_help(false)
         install:flag "-v --verbose"
         assert.equal([=[
_foo() {
    local cur prev cmd opts arg
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="foo"
    opts=""

    for arg in ${COMP_WORDS[@]:1}; do
        case "$arg" in
            install)
                cmd="install"
                break
                ;;
        esac
    done

    case "$cmd" in
        foo)
            COMPREPLY=($(compgen -W "install" -- "$cur"))
            ;;
        install)
            opts="$opts -v --verbose"
            ;;
    esac

    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _foo -o bashdefault -o default foo
]=], parser:get_bash_complete())
      end)

      it("generates completions for help command argument", function()
         local parser = Parser "foo"
            :add_help(false)
            :add_help_command {add_help = false}
         parser:command "install"
            :add_help(false)
         assert.equal([=[
_foo() {
    local cur prev cmd opts arg
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="foo"
    opts=""

    for arg in ${COMP_WORDS[@]:1}; do
        case "$arg" in
            install)
                cmd="install"
                break
                ;;
        esac
    done

    case "$cmd" in
        foo)
            COMPREPLY=($(compgen -W "help install" -- "$cur"))
            ;;
    esac

    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _foo -o bashdefault -o default foo
]=], parser:get_bash_complete())
      end)
   end)

   describe("fish completion scripts", function()
      it("generates correct completions for help flag", function()
         local parser = Parser "foo"
         assert.equal([[
complete -c foo -s h -l help -d 'Show this help message and exit'
]], parser:get_fish_complete())
      end)

      it("generates correct completions for options with required argument", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:option "--bar"
         assert.equal([[
complete -c foo -l bar -r
]], parser:get_fish_complete())
      end)

      it("generates correct completions for options with argument choices", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:option "--format"
            :choices {"short", "medium", "full"}
         assert.equal([[
complete -c foo -l format -xa 'short medium full'
]], parser:get_fish_complete())
      end)

      it("generates correct completions for commands", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:command "install"
            :add_help(false)
            :description "Install a rock."
         assert.equal([[
complete -c foo -n '__fish_use_subcommand' -xa 'install' -d 'Install a rock'
]], parser:get_fish_complete())
      end)

      it("generates correct completions for command options", function()
         local parser = Parser "foo"
            :add_help(false)
         local install = parser:command "install"
            :add_help(false)
         install:flag "-v --verbose"
         assert.equal([[
complete -c foo -n '__fish_use_subcommand' -xa 'install'
complete -c foo -n '__fish_seen_subcommand_from install' -s v -l verbose
]], parser:get_fish_complete())
      end)

      it("generates completions for help command argument", function()
         local parser = Parser "foo"
            :add_help(false)
            :add_help_command {add_help = false}
         parser:command "install"
            :add_help(false)
         assert.equal([[
complete -c foo -n '__fish_seen_subcommand_from help' -xa 'help'
complete -c foo -n '__fish_seen_subcommand_from help' -xa 'install'
complete -c foo -n '__fish_use_subcommand' -xa 'help' -d 'Show help for commands'
complete -c foo -n '__fish_use_subcommand' -xa 'install'
]], parser:get_fish_complete())
      end)

      it("uses fist sentence of descriptions", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:option "--bar"
            :description "A description with a .period. Another sentence."
         assert.equal([[
complete -c foo -l bar -r -d 'A description with a .period'
]], parser:get_fish_complete())
      end)

      it("escapes backslashes and single quotes in descriptions", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:option "--bar"
            :description "A description with illegal \\' characters."
         assert.equal([[
complete -c foo -l bar -r -d 'A description with illegal \\\' characters'
]], parser:get_fish_complete())
      end)
   end)
end)
