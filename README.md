# Valkyrie

A clean, type-safe CLI framework for Odin that makes building command-line applications simple and intuitive. Inspired by [spf13/cobra](https://github.com/spf13/cobra) for Go.

![Demo](demo.gif)

## Features

- **Type-safe flag parsing** - Support for bool, string, int, and float flags
- **Nested subcommands** - Build complex CLI hierarchies
- **Persistent flags** - Flags inherited by all subcommands
- **Command aliases** - Alternative names for commands
- **Pre/Post run hooks** - Execute code before and after commands
- **Automatic help generation** - Help text generated from command metadata
- **Short and long flags** - Both `-f` and `--flag` syntax supported
- **Required and optional flags** - Enforce required parameters
- **Default values** - Sensible defaults for all flag types
- **Memory safe** - Proper cleanup with allocator support

## Installation

```bash
# Clone the repository
git clone https://github.com/amjadjibon/valkyrie.git

# Or add it as a submodule to your project
git submodule add https://github.com/amjadjibon/valkyrie.git
```

Then import it in your Odin project:

```odin
import vk "path/to/valkyrie/valkyrie"
```

## Quick Start

Here's a simple example to get you started:

```odin
package main

import vk "path/to/valkyrie/valkyrie"
import "core:fmt"
import "core:os"

greet_handler :: proc(ctx: ^vk.Context) -> bool {
    name := vk.get_flag_string(ctx, "name")
    fmt.printfln("Hello, %s!", name)
    return true
}

main :: proc() {
    app := vk.app_create("myapp", "1.0.0", "A simple CLI application")

    greet_cmd := vk.command_create("greet", "Greet someone by name")
    vk.command_add_flag(greet_cmd, vk.flag_string("name", "n", "Name to greet", "World"))
    vk.command_set_handler(greet_cmd, greet_handler)
    vk.command_add_subcommand(app.root, greet_cmd)

    os.exit(vk.app_run(app))
}
```

## Usage

### Creating an Application

```odin
app := vk.app_create(
    "myapp",           // Application name
    "1.0.0",           // Version
    "App description", // Description
    context.temp_allocator,  // Optional allocator
)
```

### Creating Commands

```odin
cmd := vk.command_create("command", "Command description")
vk.command_set_handler(cmd, my_handler)
vk.command_add_subcommand(app.root, cmd)
```

### Adding Flags

Valkyrie supports four flag types:

```odin
// Boolean flag
vk.command_add_flag(cmd, vk.flag_bool("verbose", "v", "Enable verbose output"))

// String flag with default
vk.command_add_flag(cmd, vk.flag_string("name", "n", "Your name", "default"))

// Integer flag with default
vk.command_add_flag(cmd, vk.flag_int("port", "p", "Port number", 8080))

// Float flag with default
vk.command_add_flag(cmd, vk.flag_float("ratio", "r", "Ratio value", 1.0))

// Required flag (no default needed)
vk.command_add_flag(cmd, vk.flag_string("config", "c", "Config file", required=true))
```

### Writing Command Handlers

```odin
my_handler :: proc(ctx: ^vk.Context) -> bool {
    // Get flag values
    name := vk.get_flag_string(ctx, "name")
    count := vk.get_flag_int(ctx, "count")
    verbose := vk.get_flag_bool(ctx, "verbose")
    ratio := vk.get_flag_float(ctx, "ratio")

    // Access positional arguments
    for arg in ctx.args {
        fmt.println(arg)
    }

    // Return true for success, false for error
    return true
}
```

### Nested Subcommands

Create hierarchical command structures:

```odin
// Create parent command
server_cmd := vk.command_create("server", "Server management")

// Create subcommands
start_cmd := vk.command_create("start", "Start the server")
vk.command_add_flag(start_cmd, vk.flag_int("port", "p", "Port", 8080))
vk.command_set_handler(start_cmd, start_handler)

stop_cmd := vk.command_create("stop", "Stop the server")
vk.command_set_handler(stop_cmd, stop_handler)

// Add subcommands to parent
vk.command_add_subcommand(server_cmd, start_cmd)
vk.command_add_subcommand(server_cmd, stop_cmd)

// Add to root
vk.command_add_subcommand(app.root, server_cmd)
```

Usage:
```bash
./myapp server start --port 3000
./myapp server stop
```

### Persistent Flags

Persistent flags are inherited by all subcommands:

```odin
// Add a persistent flag to root (available to all commands)
vk.command_add_persistent_flag(app.root, vk.flag_bool("verbose", "v", "Enable verbose output"))

// Now --verbose works on any subcommand
// ./myapp --verbose greet
// ./myapp greet --verbose  (same effect)
```

### Command Aliases

Add alternative names for commands:

```odin
// Create command with alias
list_cmd := vk.command_create("list", "List items")
vk.command_add_alias(list_cmd, "ls")      // 'ls' now works like 'list'

server_cmd := vk.command_create("server", "Server commands")
vk.command_add_alias(server_cmd, "srv")   // 'srv' now works like 'server'
```

Usage:
```bash
./myapp ls              # Same as ./myapp list
./myapp srv start       # Same as ./myapp server start
```

### Pre/Post Run Hooks

Execute code before and after command handlers:

```odin
// Pre-run hook
setup_hook :: proc(ctx: ^vk.Context) -> bool {
    fmt.println("Setting up...")
    return true
}

// Post-run hook
cleanup_hook :: proc(ctx: ^vk.Context) -> bool {
    fmt.println("Cleaning up...")
    return true
}

// Set hooks on a command
vk.command_set_pre_run(cmd, setup_hook)
vk.command_set_post_run(cmd, cleanup_hook)

// Persistent hooks (inherited by subcommands)
vk.command_set_persistent_pre_run(app.root, global_setup)
vk.command_set_persistent_post_run(app.root, global_cleanup)
```

Hook execution order:
1. Persistent pre-run (root → leaf)
2. Pre-run
3. Handler
4. Post-run
5. Persistent post-run (leaf → root)

## Flag Syntax

Valkyrie supports multiple flag syntax styles:

```bash
# Long flags
--flag value
--flag=value

# Short flags
-f value
-f=value
-fvalue          # Value immediately after short flag

# Boolean flags
--verbose        # Sets to true
--verbose=true
--verbose=false

# Built-in flags
--help, -h       # Show help
--version, -V    # Show version
```

## Examples

A complete example application is provided in `examples/mycli/`. The example is organized into multiple files:

```
examples/mycli/
├── main.odin        # Entry point
├── root.odin        # Root setup + persistent hooks
└── cmd/
    ├── greet.odin   # Greet command
    ├── math.odin    # Math commands (add, multiply)
    ├── list.odin    # List command
    └── server.odin  # Server commands (info, start)
```

Build and run it:

```bash
# Build and run all checks
make

# Or individual targets
make build-example
make test
make check
make lint

# Run with various commands
./build/mycli greet --name Alice
./build/mycli greet -v --name Alice      # With verbose persistent flag
./build/mycli math add --a 5 --b 10
./build/mycli ls                          # Using alias
./build/mycli srv start -p3000            # Using alias + short flag
```

### Example Commands

The example application demonstrates:

- **greet** - Simple command with string, int, and bool flags
- **math** - Parent command with subcommands
  - **add** - Add two integers (required flags)
  - **multiply** - Multiply two floats (required flags)
- **list** (alias: `ls`) - List filtering with optional flags
- **server** (alias: `srv`) - Server management with subcommands
  - **info** - Display server information
  - **start** - Start server with configuration

## API Reference

### Application Functions

| Function | Description |
|----------|-------------|
| `app_create(name, version, description, allocator)` | Create a new CLI application |
| `app_destroy(app)` | Free application resources |
| `app_run(app, args)` | Parse args and run the appropriate command |

### Command Functions

| Function | Description |
|----------|-------------|
| `command_create(name, description, handler, allocator)` | Create a new command |
| `command_destroy(cmd)` | Free command resources |
| `command_add_flag(cmd, flag)` | Add a flag to a command |
| `command_add_persistent_flag(cmd, flag)` | Add a flag inherited by subcommands |
| `command_add_subcommand(parent, child)` | Add a subcommand |
| `command_add_alias(cmd, alias)` | Add an alternative name |
| `command_set_handler(cmd, handler)` | Set the command handler |
| `command_set_pre_run(cmd, handler)` | Set pre-run hook |
| `command_set_post_run(cmd, handler)` | Set post-run hook |
| `command_set_persistent_pre_run(cmd, handler)` | Set inherited pre-run hook |
| `command_set_persistent_post_run(cmd, handler)` | Set inherited post-run hook |

### Flag Helpers

| Function | Description |
|----------|-------------|
| `flag_bool(name, short, description, default)` | Create a boolean flag |
| `flag_string(name, short, description, default, required)` | Create a string flag |
| `flag_int(name, short, description, default, required)` | Create an integer flag |
| `flag_float(name, short, description, default, required)` | Create a float flag |

### Context Helpers

| Function | Description |
|----------|-------------|
| `get_flag_bool(ctx, name)` | Get boolean flag value |
| `get_flag_string(ctx, name)` | Get string flag value |
| `get_flag_int(ctx, name)` | Get integer flag value |
| `get_flag_float(ctx, name)` | Get float flag value |

### Context Structure

```odin
Context :: struct {
    args:      []string,               // Positional arguments
    flags:     map[string]Flag_Value,  // Parsed flag values
    command:   ^Command,               // Current command being executed
    allocator: mem.Allocator,          // Allocator to use
}
```

## Development

```bash
# Run all checks (clean, test, check, lint, build)
make

# Individual targets
make test           # Run unit tests
make check          # Static type checking
make lint           # Vet warnings + style checks
make build-example  # Build the example
make run-example    # Build and run the example
make clean          # Remove build artifacts
```

## Design Philosophy

Valkyrie is designed with these principles in mind:

1. **Type Safety** - Leverage Odin's type system for safer CLI parsing
2. **Simplicity** - Clean, intuitive API that's easy to learn
3. **Explicitness** - No magic, clear control flow
4. **Memory Safety** - Proper allocator support and cleanup
5. **Composability** - Build complex CLIs from simple building blocks
6. **Cobra-like** - Familiar patterns from Go's popular CLI framework

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Built with [Odin](https://odin-lang.org/)
- Inspired by [spf13/cobra](https://github.com/spf13/cobra)
