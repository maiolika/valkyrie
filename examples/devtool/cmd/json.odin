package cmd

import vk "../../../valkyrie"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

// JSON utilities command
make_json_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("json", "JSON manipulation utilities")

	vk.command_add_subcommand(cmd, make_json_format_cmd())
	vk.command_add_subcommand(cmd, make_json_minify_cmd())
	vk.command_add_subcommand(cmd, make_json_validate_cmd())

	return cmd
}

// --- Format subcommand ---

make_json_format_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("format", "Pretty print JSON file")
	vk.command_add_alias(cmd, "fmt")
	vk.command_add_flag(cmd, vk.flag_int("indent", "i", "Indentation spaces", 2))
	vk.command_set_handler(cmd, json_format_handler)
	return cmd
}

json_format_handler :: proc(ctx: ^vk.Context) -> bool {
	if len(ctx.args) == 0 {
		fmt.eprintln("Error: please provide a JSON file path")
		return false
	}

	filepath := ctx.args[0]
	indent := vk.get_flag_int(ctx, "indent")
	verbose := vk.get_flag_bool(ctx, "verbose")

	if verbose {
		fmt.printfln("Formatting: %s (indent: %d)", filepath, indent)
	}

	// Read file
	data, ok := os.read_entire_file(filepath)
	if !ok {
		fmt.eprintfln("Error: could not read file '%s'", filepath)
		return false
	}
	defer delete(data)

	// Parse JSON
	parsed, err := json.parse(data)
	if err != .None {
		fmt.eprintfln("Error: invalid JSON - %v", err)
		return false
	}
	defer json.destroy_value(parsed)

	// Format with indentation
	indent_str := strings.repeat(" ", indent)
	defer delete(indent_str)

	formatted, marshal_err := json.marshal(parsed, {pretty = true})
	if marshal_err != nil {
		fmt.eprintln("Error: could not format JSON")
		return false
	}
	defer delete(formatted)

	fmt.println(string(formatted))
	return true
}

// --- Minify subcommand ---

make_json_minify_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("minify", "Minify JSON file (remove whitespace)")
	vk.command_add_alias(cmd, "min")
	vk.command_set_handler(cmd, json_minify_handler)
	return cmd
}

json_minify_handler :: proc(ctx: ^vk.Context) -> bool {
	if len(ctx.args) == 0 {
		fmt.eprintln("Error: please provide a JSON file path")
		return false
	}

	filepath := ctx.args[0]
	verbose := vk.get_flag_bool(ctx, "verbose")

	if verbose {
		fmt.printfln("Minifying: %s", filepath)
	}

	// Read file
	data, ok := os.read_entire_file(filepath)
	if !ok {
		fmt.eprintfln("Error: could not read file '%s'", filepath)
		return false
	}
	defer delete(data)

	// Parse JSON
	parsed, err := json.parse(data)
	if err != .None {
		fmt.eprintfln("Error: invalid JSON - %v", err)
		return false
	}
	defer json.destroy_value(parsed)

	// Marshal without pretty printing
	minified, marshal_err := json.marshal(parsed)
	if marshal_err != nil {
		fmt.eprintln("Error: could not minify JSON")
		return false
	}
	defer delete(minified)

	fmt.println(string(minified))
	return true
}

// --- Validate subcommand ---

make_json_validate_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("validate", "Validate JSON file")
	vk.command_add_alias(cmd, "check")
	vk.command_set_handler(cmd, json_validate_handler)
	return cmd
}

json_validate_handler :: proc(ctx: ^vk.Context) -> bool {
	if len(ctx.args) == 0 {
		fmt.eprintln("Error: please provide a JSON file path")
		return false
	}

	filepath := ctx.args[0]
	verbose := vk.get_flag_bool(ctx, "verbose")

	if verbose {
		fmt.printfln("Validating: %s", filepath)
	}

	// Read file
	data, ok := os.read_entire_file(filepath)
	if !ok {
		fmt.eprintfln("Error: could not read file '%s'", filepath)
		return false
	}
	defer delete(data)

	// Parse JSON
	parsed, err := json.parse(data)
	if err != .None {
		fmt.eprintfln("✗ Invalid JSON: %v", err)
		return false
	}
	json.destroy_value(parsed)

	fmt.printfln("✓ Valid JSON: %s", filepath)
	return true
}
