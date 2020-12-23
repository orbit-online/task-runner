# Generic CLI task runner

Run all executables local to you project behind namespace (`orb`).

## Example

Consider this example project where scripts, tasks and command line utilities
is scattered over time through out the project, or you just keep
the scripts semantically separated, and then have to fight your way
through the directory structure to find the scripts in order to invoke them.

`orb` helps keeping your local project tools, scripts and utilities easily
accessible at all times.

```
/~project
  |-bin
    |-pack.js (chmod +x)
  |-node_modules
    |-.bin
      | webpack
  |-scripts
    |-lint.sh (chmod +x)
    |-test.sh (chmod -x)
  |-.env (ORB_NODE_MODULES=true)
```

```shell
~project $ orb lint
Running linter

~project $ orb test
Unable to find any tasks matching "test"

~project/deeply/nested/structure $ orb pack
Packing everything

~project $ orb webpack
Running webpack...
```

## Installation

via npm

```shell
$ npm init @orbit-online/task-runner [TASK RUNNER NAME]
```

via npx

```shell
$ npx @orbit-online/create-task-runner [TASK RUNNER NAME]
```

or yarn

```shell
$ yarn create @orbit-online/task-runner [TASK RUNNER NAME]
```

Put in the name of the executable you want available in place of `[TASK RUNNER NAME]`.
if omitted the name `orb` will be used, other popular names are `dev` or `run`.

The default installation prefix is `/usr/local/bin` this can be modified by setting
the `ORB_INSTALL_PREFIX` environment variable.

### Configuration

There are minor tweaks that can be done via an .env file (dotenv) in the root
of you project.

The project path can be configured via `PROJECT_PATH` or `ORB_PROJECT_PATH`
variables. `ORB_PROJECT_PATH` takes precedence over `PROJECT_PATH`.
However if no project path is configured, `orb` will try guess where your project root is located.

| Environment variable   | Default value                                                                                                                         | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| :--------------------- | :------------------------------------------------------------------------------------------------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PROJECT_PATH`         | `""`                                                                                                                                  | This value controls where `orb` consider the root path of the project is, thus where to look for executables from. It can be superseded by `ORB_PROJECT_PATH`.                                                                                                                                                                                                                                                                                                                                                                                                              |
| `ORB_PROJECT_PATH`     | `$PROJECT_PATH`                                                                                                                       | Overrides `PROJECT_PATH`. If neither `PROJECT_PATH` nor `ORB_PROJECT_PATH` is set, `orb` will traverse from current working directory and traverse towards `/` (root) and try to guess where the project root will be. Things such as `.git` and `node_modules` directories or `.env` and `package.json` files are considered. More will probably come later. If the guessing mechanism isn't sufficient place a `.env` file in the root of you project and use the `PROJECT_PATH` or `ORB_PROJECT_PATH` variables to control where `orb` should look for executables from. |
| `ORB_BIN_PATHS`        | `("$ORB_PROJECT_PATH/.bin" "$ORB_PROJECT_PATH/bin" "$ORB_PROJECT_PATH/scripts" "$ORB_PROJECT_PATH/tasks" "$ORB_PROJECT_PATH/tools" )` | The directories to look for executables within. NB! per default the task finder mechanism won't recursive inside the `ORB_BIN_PATHS`, this behavior can however be altered by setting `ORB_BIN_PATH_RECURSE=true`.                                                                                                                                                                                                                                                                                                                                                          |
| `ORB_BIN_PATH_RECURSE` | `false`                                                                                                                               | Controlling whether or not the task finder mechanism should look for tasks recursively from the `ORB_BIN_PATHS`.                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `ORB_NODE_MODULES`     | `false`                                                                                                                               | Include local `node_modules/.bin` to resolution path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `ORB_HOME_BIN`         | `false`                                                                                                                               | Consider home bin paths `$HOME/.local/bin`, `$HOME/.bin`, `$HOME/bin` in the task runners search path                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
