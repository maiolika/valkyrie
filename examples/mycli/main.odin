package main

import vk "../../valkyrie"
import "core:fmt"
import "core:os"

// Example: greet command handler
greet_handler :: proc(ctx: ^vk.Context) -> bool {
	name := vk.get_flag_string(ctx, "name")
	count := vk.get_flag_int(ctx, "count")
	uppercase := vk.get_flag_bool(ctx, "uppercase")

	if count < 0 {
		fmt.eprintln("Error: count must be a positive number")
		return false
	}

	if count > 100 {
		fmt.eprintln("Error: count cannot exceed 100")
		return false
	}

	if uppercase {
		// Simple uppercase conversion - allocate once
		greeting := fmt.aprintf("Hello, %s!", name)
		defer delete(greeting)

		greeting_upper := make([]u8, len(greeting))
		defer delete(greeting_upper)
		for i := 0; i < len(greeting); i += 1 {
			c := greeting[i]
			if c >= 'a' && c <= 'z' {
				greeting_upper[i] = c - 32
			} else {
				greeting_upper[i] = c
			}
		}

		for i := 0; i < count; i += 1 {
			fmt.println(string(greeting_upper))
		}
	} else {
		// Use tprintf without allocation when uppercase is false
		for i := 0; i < count; i += 1 {
			fmt.printfln("Hello, %s!", name)
		}
	}

	return true
}

// Example: add command handler
add_handler :: proc(ctx: ^vk.Context) -> bool {
	a := vk.get_flag_int(ctx, "a")
	b := vk.get_flag_int(ctx, "b")

	result := a + b
	fmt.printfln("%d + %d = %d", a, b, result)

	return true
}

// Example: multiply command handler
multiply_handler :: proc(ctx: ^vk.Context) -> bool {
	x := vk.get_flag_float(ctx, "x")
	y := vk.get_flag_float(ctx, "y")

	result := x * y
	fmt.printfln("%.2f * %.2f = %.2f", x, y, result)

	return true
}

// Example: list command handler
list_handler :: proc(ctx: ^vk.Context) -> bool {
	verbose := vk.get_flag_bool(ctx, "verbose")
	filter := vk.get_flag_string(ctx, "filter")

	items := []string{"apple", "banana", "cherry", "date", "elderberry"}

	fmt.println("Items:")
	found_count := 0
	for item in items {
		if filter != "" {
			// Simple substring check
			contains := false
			if len(filter) <= len(item) {
				for i := 0; i <= len(item) - len(filter); i += 1 {
					match := true
					for j := 0; j < len(filter); j += 1 {
						if item[i + j] != filter[j] {
							match = false
							break
						}
					}
					if match {
						contains = true
						break
					}
				}
			}
			if !contains {
				continue
			}
		}

		found_count += 1
		if verbose {
			fmt.printfln("  - %s (length: %d)", item, len(item))
		} else {
			fmt.printfln("  - %s", item)
		}
	}

	if filter != "" && found_count == 0 {
		fmt.eprintfln("Error: no items found matching filter '%s'", filter)
		return false
	}

	return true
}

// Example: info subcommand for server command
server_info_handler :: proc(ctx: ^vk.Context) -> bool {
	fmt.println("Server Information:")
	fmt.println("  Status: Running")
	fmt.println("  Port: 8080")
	fmt.println("  Version: 1.0.0")
	return true
}

// Example: start subcommand for server command
server_start_handler :: proc(ctx: ^vk.Context) -> bool {
	port := vk.get_flag_int(ctx, "port")
	daemon := vk.get_flag_bool(ctx, "daemon")

	if port < 1024 {
		fmt.eprintfln("Error: port must be 1024 or higher (privileged ports require root)")
		return false
	}

	if port > 65535 {
		fmt.eprintfln("Error: port must be 65535 or lower")
		return false
	}

	fmt.printfln("Starting server on port %d", port)
	if daemon {
		fmt.println("Running in daemon mode")
	}
	fmt.println("Server started successfully!")

	return true
}

main :: proc() {
	// Create the app
	app := vk.app_create(
		"mycli",
		"1.0.0",
		"An example vk application built with Valkyrie",
		context.temp_allocator,
	)

	// Create greet command
	greet_cmd := vk.command_create("greet", "Greet someone by name")
	vk.command_add_flag(greet_cmd, vk.flag_string("name", "n", "Name to greet", "World"))
	vk.command_add_flag(greet_cmd, vk.flag_int("count", "c", "Number of times to greet", 1))
	vk.command_add_flag(greet_cmd, vk.flag_bool("uppercase", "u", "Print in uppercase"))
	vk.command_set_handler(greet_cmd, greet_handler)
	vk.command_add_subcommand(app.root, greet_cmd)

	// Create math command with subcommands
	math_cmd := vk.command_create("math", "Mathematical operations")

	add_cmd := vk.command_create("add", "Add two numbers")
	vk.command_add_flag(add_cmd, vk.flag_int("a", "", "First number", required = true))
	vk.command_add_flag(add_cmd, vk.flag_int("b", "", "Second number", required = true))
	vk.command_set_handler(add_cmd, add_handler)
	vk.command_add_subcommand(math_cmd, add_cmd)

	multiply_cmd := vk.command_create("multiply", "Multiply two numbers")
	vk.command_add_flag(multiply_cmd, vk.flag_float("x", "", "First number", required = true))
	vk.command_add_flag(multiply_cmd, vk.flag_float("y", "", "Second number", required = true))
	vk.command_set_handler(multiply_cmd, multiply_handler)
	vk.command_add_subcommand(math_cmd, multiply_cmd)

	vk.command_add_subcommand(app.root, math_cmd)

	// Create list command
	list_cmd := vk.command_create("list", "List items")
	vk.command_add_flag(list_cmd, vk.flag_bool("verbose", "v", "Show detailed information"))
	vk.command_add_flag(list_cmd, vk.flag_string("filter", "f", "Filter items by substring"))
	vk.command_set_handler(list_cmd, list_handler)
	vk.command_add_subcommand(app.root, list_cmd)

	// Create server command with subcommands
	server_cmd := vk.command_create("server", "Server management commands")

	server_info_cmd := vk.command_create("info", "Show server information")
	vk.command_set_handler(server_info_cmd, server_info_handler)
	vk.command_add_subcommand(server_cmd, server_info_cmd)

	server_start_cmd := vk.command_create("start", "Start the server")
	vk.command_add_flag(server_start_cmd, vk.flag_int("port", "p", "Port to listen on", 8080))
	vk.command_add_flag(server_start_cmd, vk.flag_bool("daemon", "d", "Run as daemon"))
	vk.command_set_handler(server_start_cmd, server_start_handler)
	vk.command_add_subcommand(server_cmd, server_start_cmd)

	vk.command_add_subcommand(app.root, server_cmd)

	// Run the app
	exit_code := vk.app_run(app)

	// Cleanup before exit
	free_all(context.temp_allocator)

	os.exit(exit_code)
}
