Shell completions
=================

Argparse supports generating shell completion scripts for Bash, Zsh, and Fish.
The completion scripts support completing options, commands, and argument
choices.

The Parser methods ``:get_bash_complete()``, ``get_zsh_complete()``, and
``:get_fish_complete()`` return completion scripts as a string.

Adding a completion option or command
-------------------------------------

A ``--completion`` option can be added to the parser using the
``:add_complete([value])`` method. The optional ``value`` argument is a string
or table used to configure the option.

.. code-block:: lua
   :linenos:

   local parser = argparse()
      :add_complete()

.. code-block:: none

   $ lua script.lua -h

.. code-block:: none

   Usage: script.lua [-h] [--completion {bash,zsh,fish}]

   Options:
      -h, --help            Show this help message and exit.
      --completion {bash,zsh,fish}
                            Output a shell completion script for the specified shell.

A similar ``completion`` command can be added to the parser using the
``:add_complete_command([value])`` method.

Activating completions
----------------------

Bash
^^^^

Save the generated completion script at
``~/.local/share/bash-completion/completions/script.lua`` or add the following
line to the ``~/.bashrc``:

.. code-block:: bash

   source <(script.lua --completion bash)

Zsh
^^^

The completion script should be placed in a directory in the ``$fpath``.  A new
directory can be added to to the ``$fpath`` by adding e.g.
``fpath=(~/.zfunc $fpath)`` in the ``~/.zshrc`` before ``compinit``. Save the
completion script with:

.. code-block:: none

   $ script.lua --completion zsh > ~/.zfunc/_script.lua

Fish
^^^^

Save the completion script at ``~/.config/fish/completions/script.lua.fish`` or
add the following line to the file ``~/.config/fish/config.fish``:

.. code-block:: fish

   script.lua --completion fish | source
