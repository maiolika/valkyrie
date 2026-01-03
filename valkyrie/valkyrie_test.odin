package valkyrie

import "core:testing"

// ============================================================================
// Flag Creation Tests
// ============================================================================

@(test)
test_flag_bool_creation :: proc(t: ^testing.T) {
	flag := flag_bool("verbose", "v", "Enable verbose")
	testing.expect_value(t, flag.name, "verbose")
	testing.expect_value(t, flag.short, "v")
	testing.expect_value(t, flag.description, "Enable verbose")
	testing.expect_value(t, flag.type, Flag_Type.Bool)
	testing.expect_value(t, flag.required, false)
	testing.expect_value(t, flag.default_val.(bool), false)
}

@(test)
test_flag_bool_with_default :: proc(t: ^testing.T) {
	flag := flag_bool("debug", "d", "Debug mode", true)
	testing.expect_value(t, flag.default_val.(bool), true)
}

@(test)
test_flag_string_creation :: proc(t: ^testing.T) {
	flag := flag_string("name", "n", "Your name", "World")
	testing.expect_value(t, flag.name, "name")
	testing.expect_value(t, flag.short, "n")
	testing.expect_value(t, flag.type, Flag_Type.String)
	testing.expect_value(t, flag.default_val.(string), "World")
	testing.expect_value(t, flag.required, false)
}

@(test)
test_flag_string_required :: proc(t: ^testing.T) {
	flag := flag_string("config", "c", "Config file", required = true)
	testing.expect_value(t, flag.required, true)
}

@(test)
test_flag_int_creation :: proc(t: ^testing.T) {
	flag := flag_int("port", "p", "Port number", 8080)
	testing.expect_value(t, flag.name, "port")
	testing.expect_value(t, flag.type, Flag_Type.Int)
	testing.expect_value(t, flag.default_val.(int), 8080)
}

@(test)
test_flag_float_creation :: proc(t: ^testing.T) {
	flag := flag_float("ratio", "r", "Ratio value", 1.5)
	testing.expect_value(t, flag.name, "ratio")
	testing.expect_value(t, flag.type, Flag_Type.Float)
	testing.expect_value(t, flag.default_val.(f64), 1.5)
}

// ============================================================================
// Command Creation Tests
// ============================================================================

@(test)
test_command_create :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)

	testing.expect_value(t, cmd.name, "test")
	testing.expect_value(t, cmd.description, "Test command")
	testing.expect(t, cmd.handler == nil, "Handler should be nil by default")
	testing.expect_value(t, len(cmd.flags), 0)
	testing.expect_value(t, len(cmd.subcommands), 0)
}

@(test)
test_command_add_flag :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)

	command_add_flag(cmd, flag_bool("verbose", "v", "Verbose"))
	command_add_flag(cmd, flag_string("name", "n", "Name", "World"))

	testing.expect_value(t, len(cmd.flags), 2)
	testing.expect_value(t, cmd.flags[0].name, "verbose")
	testing.expect_value(t, cmd.flags[1].name, "name")
}

@(test)
test_command_add_persistent_flag :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)

	command_add_persistent_flag(cmd, flag_bool("verbose", "v", "Verbose"))

	testing.expect_value(t, len(cmd.persistent_flags), 1)
	testing.expect_value(t, cmd.persistent_flags[0].name, "verbose")
}

@(test)
test_command_add_subcommand :: proc(t: ^testing.T) {
	parent := command_create("parent", "Parent command")
	child := command_create("child", "Child command")
	defer command_destroy(parent) // This will also destroy child

	command_add_subcommand(parent, child)

	testing.expect_value(t, len(parent.subcommands), 1)
	testing.expect_value(t, parent.subcommands[0].name, "child")
	testing.expect(t, child.parent == parent, "Child's parent should be set")
}

@(test)
test_command_add_alias :: proc(t: ^testing.T) {
	cmd := command_create("list", "List items")
	defer command_destroy(cmd)

	command_add_alias(cmd, "ls")
	command_add_alias(cmd, "l")

	testing.expect_value(t, len(cmd.aliases), 2)
	testing.expect_value(t, cmd.aliases[0], "ls")
	testing.expect_value(t, cmd.aliases[1], "l")
}

// ============================================================================
// Handler Tests
// ============================================================================

test_handler_called := false

test_handler :: proc(ctx: ^Context) -> bool {
	test_handler_called = true
	return true
}

@(test)
test_command_set_handler :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)

	command_set_handler(cmd, test_handler)
	testing.expect(t, cmd.handler != nil, "Handler should be set")
}

// ============================================================================
// Parse Args Tests
// ============================================================================

@(test)
test_parse_args_empty :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)

	ctx, parsed_cmd, ok := parse_args(cmd, {})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse empty args successfully")
	testing.expect(t, parsed_cmd == cmd, "Should return the same command")
}

@(test)
test_parse_args_bool_flag_long :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)
	command_add_flag(cmd, flag_bool("verbose", "v", "Verbose"))

	ctx, _, ok := parse_args(cmd, {"--verbose"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse --verbose")
	testing.expect_value(t, get_flag_bool(&ctx, "verbose"), true)
}

@(test)
test_parse_args_bool_flag_short :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)
	command_add_flag(cmd, flag_bool("verbose", "v", "Verbose"))

	ctx, _, ok := parse_args(cmd, {"-v"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse -v")
	testing.expect_value(t, get_flag_bool(&ctx, "verbose"), true)
}

@(test)
test_parse_args_string_flag :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)
	command_add_flag(cmd, flag_string("name", "n", "Name", "World"))

	ctx, _, ok := parse_args(cmd, {"--name", "Alice"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse --name Alice")
	testing.expect_value(t, get_flag_string(&ctx, "name"), "Alice")
}

@(test)
test_parse_args_string_flag_equals :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)
	command_add_flag(cmd, flag_string("name", "n", "Name", "World"))

	ctx, _, ok := parse_args(cmd, {"--name=Bob"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse --name=Bob")
	testing.expect_value(t, get_flag_string(&ctx, "name"), "Bob")
}

@(test)
test_parse_args_int_flag :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)
	command_add_flag(cmd, flag_int("port", "p", "Port", 8080))

	ctx, _, ok := parse_args(cmd, {"--port", "3000"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse --port 3000")
	testing.expect_value(t, get_flag_int(&ctx, "port"), 3000)
}

@(test)
test_parse_args_short_flag_value :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)
	command_add_flag(cmd, flag_int("port", "p", "Port", 8080))

	ctx, _, ok := parse_args(cmd, {"-p3000"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse -p3000")
	testing.expect_value(t, get_flag_int(&ctx, "port"), 3000)
}

@(test)
test_parse_args_default_values :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)
	command_add_flag(cmd, flag_string("name", "n", "Name", "World"))
	command_add_flag(cmd, flag_int("count", "c", "Count", 5))

	ctx, _, ok := parse_args(cmd, {})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should use defaults")
	testing.expect_value(t, get_flag_string(&ctx, "name"), "World")
	testing.expect_value(t, get_flag_int(&ctx, "count"), 5)
}

@(test)
test_parse_args_required_flag_missing :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)
	command_add_flag(cmd, flag_string("config", "c", "Config", required = true))

	_, _, ok := parse_args(cmd, {})
	// Note: on failure, parse_args cleans up ctx.flags and ctx.args via defer
	// So we don't need to delete them here

	testing.expect(t, !ok, "Should fail when required flag is missing")
}

@(test)
test_parse_args_required_flag_provided :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)
	command_add_flag(cmd, flag_string("config", "c", "Config", required = true))

	ctx, _, ok := parse_args(cmd, {"--config", "app.yaml"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should succeed when required flag is provided")
	testing.expect_value(t, get_flag_string(&ctx, "config"), "app.yaml")
}

@(test)
test_parse_args_positional_args :: proc(t: ^testing.T) {
	cmd := command_create("test", "Test command")
	defer command_destroy(cmd)

	ctx, _, ok := parse_args(cmd, {"file1.txt", "file2.txt"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse positional args")
	testing.expect_value(t, len(ctx.args), 2)
	testing.expect_value(t, ctx.args[0], "file1.txt")
	testing.expect_value(t, ctx.args[1], "file2.txt")
}

@(test)
test_parse_args_subcommand :: proc(t: ^testing.T) {
	parent := command_create("parent", "Parent")
	child := command_create("child", "Child")
	defer command_destroy(parent)
	command_add_subcommand(parent, child)
	command_add_flag(child, flag_string("name", "n", "Name", "World"))

	ctx, parsed_cmd, ok := parse_args(parent, {"child", "--name", "Test"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse subcommand")
	testing.expect(t, parsed_cmd == child, "Should return child command")
	testing.expect_value(t, get_flag_string(&ctx, "name"), "Test")
}

@(test)
test_parse_args_subcommand_alias :: proc(t: ^testing.T) {
	parent := command_create("parent", "Parent")
	child := command_create("list", "List items")
	defer command_destroy(parent)
	command_add_subcommand(parent, child)
	command_add_alias(child, "ls")

	ctx, parsed_cmd, ok := parse_args(parent, {"ls"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse subcommand via alias")
	testing.expect(t, parsed_cmd == child, "Should return child command")
}

@(test)
test_parse_args_persistent_flags :: proc(t: ^testing.T) {
	parent := command_create("parent", "Parent")
	child := command_create("child", "Child")
	defer command_destroy(parent)

	command_add_persistent_flag(parent, flag_bool("verbose", "v", "Verbose"))
	command_add_subcommand(parent, child)

	ctx, parsed_cmd, ok := parse_args(parent, {"child", "--verbose"})
	defer {
		delete(ctx.flags)
		delete(ctx.args)
	}

	testing.expect(t, ok, "Should parse persistent flag on child")
	testing.expect(t, parsed_cmd == child, "Should return child command")
	testing.expect_value(t, get_flag_bool(&ctx, "verbose"), true)
}

// ============================================================================
// App Tests
// ============================================================================

@(test)
test_app_create :: proc(t: ^testing.T) {
	app := app_create("testapp", "1.0.0", "Test application")
	defer app_destroy(app)

	testing.expect_value(t, app.name, "testapp")
	testing.expect_value(t, app.version, "1.0.0")
	testing.expect_value(t, app.description, "Test application")
	testing.expect(t, app.root != nil, "Root command should exist")
}

// ============================================================================
// Context Helper Tests
// ============================================================================

@(test)
test_get_flag_bool_missing :: proc(t: ^testing.T) {
	ctx := Context{}
	ctx.flags = make(map[string]Flag_Value)
	defer delete(ctx.flags)

	result := get_flag_bool(&ctx, "nonexistent")
	testing.expect_value(t, result, false)
}

@(test)
test_get_flag_string_missing :: proc(t: ^testing.T) {
	ctx := Context{}
	ctx.flags = make(map[string]Flag_Value)
	defer delete(ctx.flags)

	result := get_flag_string(&ctx, "nonexistent")
	testing.expect_value(t, result, "")
}

@(test)
test_get_flag_int_missing :: proc(t: ^testing.T) {
	ctx := Context{}
	ctx.flags = make(map[string]Flag_Value)
	defer delete(ctx.flags)

	result := get_flag_int(&ctx, "nonexistent")
	testing.expect_value(t, result, 0)
}

@(test)
test_get_flag_float_missing :: proc(t: ^testing.T) {
	ctx := Context{}
	ctx.flags = make(map[string]Flag_Value)
	defer delete(ctx.flags)

	result := get_flag_float(&ctx, "nonexistent")
	testing.expect_value(t, result, 0.0)
}
