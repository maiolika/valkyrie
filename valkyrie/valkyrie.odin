// Valkyrie - A CLI framework for Odin
//
// Valkyrie provides a clean, type-safe API for building command-line applications
// with support for subcommands, flags, and automatic help generation.
//
package valkyrie

import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

// Flag types
Flag_Type :: enum {
	Bool,
	String,
	Int,
	Float,
}

// Flag definition
Flag :: struct {
	name:        string,
	short:       string,
	description: string,
	type:        Flag_Type,
	required:    bool,
	default_val: union {
		bool,
		string,
		int,
		f64,
	},
}

// Parsed flag value
Flag_Value :: union {
	bool,
	string,
	int,
	f64,
}

// Command context passed to command handlers
Context :: struct {
	args:      []string,
	flags:     map[string]Flag_Value,
	command:   ^Command,
	allocator: mem.Allocator,
}

// Command handler function type
Command_Fn :: #type proc(ctx: ^Context) -> (ok: bool)

// Command handler function type
Help_Fn :: #type proc(cmd: ^Command)

// Command definition
Command :: struct {
	name:                string,
	description:         string,
	usage:               string,
	aliases:             [dynamic]string,
	flags:               [dynamic]Flag,
	persistent_flags:    [dynamic]Flag,
	subcommands:         [dynamic]^Command,
	handler:             Command_Fn,
	pre_run:             Command_Fn,
	post_run:            Command_Fn,
	persistent_pre_run:  Command_Fn,
	persistent_post_run: Command_Fn,
	help_fn:             Help_Fn,
	parent:              ^Command,
	allocator:           mem.Allocator,
}

// Application structure
App :: struct {
	name:        string,
	version:     string,
	description: string,
	root:        ^Command,
	allocator:   mem.Allocator,
}

// Create a new CLI application
app_create :: proc(
	name: string,
	version: string = "0.1.0",
	description: string = "",
	allocator := context.allocator,
) -> ^App {
	app := new(App, allocator)
	app.name = name
	app.version = version
	app.description = description
	app.allocator = allocator
	app.root = command_create("", description, allocator = allocator)
	return app
}

// Destroy application and free all resources
app_destroy :: proc(app: ^App) {
	if app == nil do return
	command_destroy(app.root)
	free(app, app.allocator)
}

// Create a new command
command_create :: proc(
	name: string,
	description: string = "",
	handler: Command_Fn = nil,
	allocator := context.allocator,
) -> ^Command {
	cmd := new(Command, allocator)
	cmd.name = name
	cmd.description = description
	cmd.handler = handler
	cmd.allocator = allocator
	cmd.aliases = make([dynamic]string, allocator)
	cmd.flags = make([dynamic]Flag, allocator)
	cmd.persistent_flags = make([dynamic]Flag, allocator)
	cmd.subcommands = make([dynamic]^Command, allocator)
	return cmd
}

// Destroy command and free all resources recursively
command_destroy :: proc(cmd: ^Command) {
	if cmd == nil do return

	// Destroy all subcommands first
	for subcmd in cmd.subcommands {
		command_destroy(subcmd)
	}

	delete(cmd.aliases)
	delete(cmd.flags)
	delete(cmd.persistent_flags)
	delete(cmd.subcommands)
	free(cmd, cmd.allocator)
}

// Add a flag to a command
command_add_flag :: proc(cmd: ^Command, flag: Flag) {
	append(&cmd.flags, flag)
}

// Add a persistent flag to a command (inherited by subcommands)
command_add_persistent_flag :: proc(cmd: ^Command, flag: Flag) {
	append(&cmd.persistent_flags, flag)
}

// Add a subcommand
command_add_subcommand :: proc(parent: ^Command, child: ^Command) {
	child.parent = parent
	append(&parent.subcommands, child)
}

// Add an alias for a command
command_add_alias :: proc(cmd: ^Command, alias: string) {
	append(&cmd.aliases, alias)
}

// Set command handler
command_set_handler :: proc(cmd: ^Command, handler: Command_Fn) {
	cmd.handler = handler
}

// Set custom help handler
command_set_help :: proc(cmd: ^Command, help: Help_Fn) {
    cmd.help_fn = help
}

// Set pre-run hook (runs before handler)
command_set_pre_run :: proc(cmd: ^Command, handler: Command_Fn) {
	cmd.pre_run = handler
}

// Set post-run hook (runs after handler)
command_set_post_run :: proc(cmd: ^Command, handler: Command_Fn) {
	cmd.post_run = handler
}

// Set persistent pre-run hook (inherited by subcommands, runs before pre_run)
command_set_persistent_pre_run :: proc(cmd: ^Command, handler: Command_Fn) {
	cmd.persistent_pre_run = handler
}

// Set persistent post-run hook (inherited by subcommands, runs after post_run)
command_set_persistent_post_run :: proc(cmd: ^Command, handler: Command_Fn) {
	cmd.persistent_post_run = handler
}

// Helper to create boolean flag
flag_bool :: proc(
	name: string,
	short: string = "",
	description: string = "",
	default := false,
) -> Flag {
	return Flag {
		name = name,
		short = short,
		description = description,
		type = .Bool,
		required = false,
		default_val = default,
	}
}

// Helper to create string flag
flag_string :: proc(
	name: string,
	short: string = "",
	description: string = "",
	default := "",
	required := false,
) -> Flag {
	return Flag {
		name = name,
		short = short,
		description = description,
		type = .String,
		required = required,
		default_val = default,
	}
}

// Helper to create int flag
flag_int :: proc(
	name: string,
	short: string = "",
	description: string = "",
	default := 0,
	required := false,
) -> Flag {
	return Flag {
		name = name,
		short = short,
		description = description,
		type = .Int,
		required = required,
		default_val = default,
	}
}

// Helper to create float flag
flag_float :: proc(
	name: string,
	short: string = "",
	description: string = "",
	default := 0.0,
	required := false,
) -> Flag {
	return Flag {
		name = name,
		short = short,
		description = description,
		type = .Float,
		required = required,
		default_val = default,
	}
}

// Collect persistent flags from parent chain (including current command)
collect_persistent_flags :: proc(cmd: ^Command, flags: ^[dynamic]Flag) {
	if cmd == nil do return
	// First collect from parent (so parent flags come first)
	collect_persistent_flags(cmd.parent, flags)
	// Then add this command's persistent flags
	for flag in cmd.persistent_flags {
		append(flags, flag)
	}
}

// Parse command line arguments
parse_args :: proc(
	cmd: ^Command,
	args: []string,
	allocator := context.allocator,
) -> (
	ctx: Context,
	cmd_to_run: ^Command,
	ok: bool,
) {
	ctx.flags = make(map[string]Flag_Value, allocator = allocator)
	ctx.allocator = allocator
	ctx.command = cmd
	cmd_to_run = cmd
	ok = false

	// Track which flags were explicitly provided (for required flag validation)
	provided_flags := make(map[string]bool, allocator = allocator)
	defer delete(provided_flags)

	// Ensure cleanup on error paths
	defer if !ok {
		delete(ctx.flags)
		if ctx.args != nil {
			delete(ctx.args)
		}
	}

	i := 0
	positional_args := make([dynamic]string, allocator)
	defer delete(positional_args)

	// First, set default values for command's own flags
	for flag in cmd.flags {
		switch flag.type {
		case .Bool:
			ctx.flags[flag.name] = flag.default_val.(bool)
		case .String:
			ctx.flags[flag.name] = flag.default_val.(string)
		case .Int:
			ctx.flags[flag.name] = flag.default_val.(int)
		case .Float:
			ctx.flags[flag.name] = flag.default_val.(f64)
		}
	}

	// Collect and set defaults for persistent flags from parent chain
	all_persistent_flags := make([dynamic]Flag, allocator)
	defer delete(all_persistent_flags)
	collect_persistent_flags(cmd, &all_persistent_flags)
	for flag in all_persistent_flags {
		switch flag.type {
		case .Bool:
			ctx.flags[flag.name] = flag.default_val.(bool)
		case .String:
			ctx.flags[flag.name] = flag.default_val.(string)
		case .Int:
			ctx.flags[flag.name] = flag.default_val.(int)
		case .Float:
			ctx.flags[flag.name] = flag.default_val.(f64)
		}
	}

	// Build combined flag list for parsing (command flags + persistent flags)
	all_flags := make([dynamic]Flag, allocator)
	defer delete(all_flags)
	for flag in cmd.flags {
		append(&all_flags, flag)
	}
	for flag in all_persistent_flags {
		append(&all_flags, flag)
	}

	// Parse arguments
	for i < len(args) {
		arg := args[i]

		// Check for help flag
		if arg == "-h" || arg == "--help" {
			print_help(cmd)
			return ctx, cmd_to_run, false
		}

		// Check if it's a flag
		if strings.has_prefix(arg, "--") {
			flag_name := arg[2:]
			flag_value := ""
			has_equals := false

			// Check for --flag=value syntax
			for j := 0; j < len(flag_name); j += 1 {
				if flag_name[j] == '=' {
					flag_value = flag_name[j + 1:]
					flag_name = flag_name[:j]
					has_equals = true
					break
				}
			}

			// Find the flag in combined list
			flag_found := false
			for flag in all_flags {
				if flag.name == flag_name {
					flag_found = true

					switch flag.type {
					case .Bool:
						provided_flags[flag.name] = true
						if has_equals {
							// Handle --flag=true or --flag=false
							if flag_value == "true" || flag_value == "1" {
								ctx.flags[flag.name] = true
							} else if flag_value == "false" || flag_value == "0" {
								ctx.flags[flag.name] = false
							} else {
								fmt.eprintfln("Error: invalid boolean value for --%s", flag_name)
								return ctx, cmd_to_run, false
							}
						} else {
							ctx.flags[flag.name] = true
						}
					case .String, .Int, .Float:
						provided_flags[flag.name] = true
						value := flag_value
						if !has_equals {
							i += 1
							if i >= len(args) {
								fmt.eprintfln("Error: flag --%s requires a value", flag_name)
								return ctx, cmd_to_run, false
							}
							value = args[i]
						}

						switch flag.type {
						case .String:
							ctx.flags[flag.name] = value
						case .Int:
							val, parse_ok := strconv.parse_int(value)
							if !parse_ok {
								fmt.eprintfln("Error: invalid integer value for --%s", flag_name)
								return ctx, cmd_to_run, false
							}
							ctx.flags[flag.name] = val
						case .Float:
							val, parse_ok := strconv.parse_f64(value)
							if !parse_ok {
								fmt.eprintfln("Error: invalid float value for --%s", flag_name)
								return ctx, cmd_to_run, false
							}
							ctx.flags[flag.name] = val
						case .Bool:
						// Already handled
						}
					}
					break
				}
			}

			if !flag_found {
				fmt.eprintfln("Error: unknown flag --%s", flag_name)
				return ctx, cmd_to_run, false
			}
		} else if strings.has_prefix(arg, "-") && len(arg) >= 2 {
			// Short flag
			short_name := arg[1:2]
			flag_value := ""
			has_equals := false

			// Check for -f=value or -fvalue syntax
			if len(arg) > 2 {
				if arg[2] == '=' {
					flag_value = arg[3:]
					has_equals = true
				} else {
					// Handle -fvalue syntax (value immediately after flag character)
					flag_value = arg[2:]
					has_equals = true
				}
			}

			flag_found := false
			for flag in all_flags {
				if flag.short == short_name {
					flag_found = true

					switch flag.type {
					case .Bool:
						provided_flags[flag.name] = true
						if has_equals {
							// Handle -f=true or -f=false
							if flag_value == "true" || flag_value == "1" {
								ctx.flags[flag.name] = true
							} else if flag_value == "false" || flag_value == "0" {
								ctx.flags[flag.name] = false
							} else {
								fmt.eprintfln("Error: invalid boolean value for -%s", short_name)
								return ctx, cmd_to_run, false
							}
						} else {
							ctx.flags[flag.name] = true
						}
					case .String, .Int, .Float:
						provided_flags[flag.name] = true
						value := flag_value
						if !has_equals {
							i += 1
							if i >= len(args) {
								fmt.eprintfln("Error: flag -%s requires a value", short_name)
								return ctx, cmd_to_run, false
							}
							value = args[i]
						}

						switch flag.type {
						case .String:
							ctx.flags[flag.name] = value
						case .Int:
							val, parse_ok := strconv.parse_int(value)
							if !parse_ok {
								fmt.eprintfln("Error: invalid integer value for -%s", short_name)
								return ctx, cmd_to_run, false
							}
							ctx.flags[flag.name] = val
						case .Float:
							val, parse_ok := strconv.parse_f64(value)
							if !parse_ok {
								fmt.eprintfln("Error: invalid float value for -%s", short_name)
								return ctx, cmd_to_run, false
							}
							ctx.flags[flag.name] = val
						case .Bool:
						// Already handled
						}
					}
					break
				}
			}

			if !flag_found {
				fmt.eprintfln("Error: unknown flag -%s", short_name)
				return ctx, cmd_to_run, false
			}
		} else {
			// Check if it's a subcommand (by name or alias)
			subcommand_found := false
			for subcmd in cmd.subcommands {
				// Check command name
				if subcmd.name == arg {
					subcommand_found = true
					remaining_args := args[i + 1:]
					delete(ctx.flags)
					// Note: ctx.args is not assigned yet, so no need to delete
					return parse_args(subcmd, remaining_args, allocator)
				}
				// Check aliases
				for alias in subcmd.aliases {
					if alias == arg {
						subcommand_found = true
						remaining_args := args[i + 1:]
						delete(ctx.flags)
						return parse_args(subcmd, remaining_args, allocator)
					}
				}
			}

			if !subcommand_found {
				append(&positional_args, arg)
			}
		}

		i += 1
	}

	// Convert positional args to slice
	ctx.args = slice.clone(positional_args[:], allocator)

	// Check required flags were explicitly provided
	for flag in cmd.flags {
		if flag.required {
			if flag.name not_in provided_flags {
				fmt.eprintfln("Error: required flag --%s not provided", flag.name)
				return ctx, cmd_to_run, false
			}
		}
	}

	// Check required persistent flags were explicitly provided
	for flag in all_persistent_flags {
		if flag.required {
			if flag.name not_in provided_flags {
				fmt.eprintfln("Error: required persistent flag --%s not provided", flag.name)
				return ctx, cmd_to_run, false
			}
		}
	}

	ok = true
	return ctx, cmd_to_run, true
}

// Dispatch help: calls custom function or default
print_help :: proc(cmd: ^Command) {
    if cmd.help_fn != nil {
        cmd.help_fn(cmd)
    } else {
        print_help_default(cmd)
    }
}

// Default help handler (renamed from original print_help)
print_help_default :: proc(cmd: ^Command) {
	if cmd.name != "" {
		fmt.printfln("%s - %s", cmd.name, cmd.description)
	} else {
		fmt.printfln("%s", cmd.description)
	}

	// Show aliases if present
	if len(cmd.aliases) > 0 {
		fmt.printf("Aliases: ")
		for i := 0; i < len(cmd.aliases); i += 1 {
			if i > 0 {
				fmt.printf(", ")
			}
			fmt.printf("%s", cmd.aliases[i])
		}
		fmt.println()
	}

	fmt.println()

	if cmd.usage != "" {
		fmt.printfln("Usage: %s", cmd.usage)
	} else if cmd.name != "" {
		fmt.printfln("Usage: %s [flags] [subcommands]", cmd.name)
	} else {
		fmt.println("Usage: [command] [flags] [subcommands]")
	}

	if len(cmd.flags) > 0 {
		fmt.println("\nFlags:")
		for flag in cmd.flags {
			short_str := flag.short != "" ? fmt.tprintf("-%s, ", flag.short) : "    "
			required_str := flag.required ? " (required)" : ""
			fmt.printfln("  %s--%-15s %s%s", short_str, flag.name, flag.description, required_str)
		}
	}

	// Show persistent flags (inherited from parent chain)
	all_persistent := make([dynamic]Flag, context.temp_allocator)
	collect_persistent_flags(cmd, &all_persistent)
	if len(all_persistent) > 0 {
		fmt.println("\nPersistent Flags:")
		for flag in all_persistent {
			short_str := flag.short != "" ? fmt.tprintf("-%s, ", flag.short) : "    "
			required_str := flag.required ? " (required)" : ""
			fmt.printfln("  %s--%-15s %s%s", short_str, flag.name, flag.description, required_str)
		}
	}

	if len(cmd.subcommands) > 0 {
		fmt.println("\nSubcommands:")
		for subcmd in cmd.subcommands {
			alias_str := ""
			if len(subcmd.aliases) > 0 {
				alias_str = fmt.tprintf(" (aliases: %s)", subcmd.aliases[0])
			}
			fmt.printfln("  %-15s %s%s", subcmd.name, subcmd.description, alias_str)
		}
	}
}

// Run the application
app_run :: proc(app: ^App, args: []string = nil) -> int {
	run_args := args
	if args == nil {
		run_args = os.args[1:]
	}

	// Check for version flag (use -V to avoid conflict with user -v flags)
	for arg in run_args {
		if arg == "--version" || arg == "-V" {
			fmt.printfln("%s version %s", app.name, app.version)
			return 0
		}
	}

	ctx, cmd, ok := parse_args(app.root, run_args, app.allocator)
	defer {
		delete(ctx.args)
		delete(ctx.flags)
	}

	if !ok {
		return 1
	}

	if cmd.handler == nil {
		if len(cmd.subcommands) > 0 {
			print_help(cmd)
		} else {
			fmt.println("Error: no handler defined for this command")
		}
		return 1
	}

	// Execute persistent pre-run hooks (from root to leaf)
	if !execute_persistent_pre_run(cmd, &ctx) {
		return 1
	}

	// Execute pre-run hook
	if cmd.pre_run != nil {
		if !cmd.pre_run(&ctx) {
			return 1
		}
	}

	// Execute main handler
	ok = cmd.handler(&ctx)
	if !ok {
		return 1
	}

	// Execute post-run hook
	if cmd.post_run != nil {
		if !cmd.post_run(&ctx) {
			return 1
		}
	}

	// Execute persistent post-run hooks (from leaf to root)
	if !execute_persistent_post_run(cmd, &ctx) {
		return 1
	}

	return 0
}

// Execute persistent pre-run hooks from root to leaf
execute_persistent_pre_run :: proc(cmd: ^Command, ctx: ^Context) -> bool {
	if cmd == nil do return true
	// First execute parent's persistent pre-run
	if !execute_persistent_pre_run(cmd.parent, ctx) {
		return false
	}
	// Then execute this command's persistent pre-run
	if cmd.persistent_pre_run != nil {
		if !cmd.persistent_pre_run(ctx) {
			return false
		}
	}
	return true
}

// Execute persistent post-run hooks from leaf to root
execute_persistent_post_run :: proc(cmd: ^Command, ctx: ^Context) -> bool {
	if cmd == nil do return true
	// First execute this command's persistent post-run
	if cmd.persistent_post_run != nil {
		if !cmd.persistent_post_run(ctx) {
			return false
		}
	}
	// Then execute parent's persistent post-run
	if !execute_persistent_post_run(cmd.parent, ctx) {
		return false
	}
	return true
}

// Context helper methods
get_flag_bool :: proc(ctx: ^Context, name: string) -> bool {
	if val, ok := ctx.flags[name]; ok {
		if b, is_bool := val.(bool); is_bool {
			return b
		}
	}
	return false
}

get_flag_string :: proc(ctx: ^Context, name: string) -> string {
	if val, ok := ctx.flags[name]; ok {
		if s, is_string := val.(string); is_string {
			return s
		}
	}
	return ""
}

get_flag_int :: proc(ctx: ^Context, name: string) -> int {
	if val, ok := ctx.flags[name]; ok {
		if i, is_int := val.(int); is_int {
			return i
		}
	}
	return 0
}

get_flag_float :: proc(ctx: ^Context, name: string) -> f64 {
	if val, ok := ctx.flags[name]; ok {
		if f, is_float := val.(f64); is_float {
			return f
		}
	}
	return 0.0
}
