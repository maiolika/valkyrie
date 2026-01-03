package main

import vk "../../valkyrie"
import "cmd"
import "core:fmt"

// Create the devtool application
make_app :: proc() -> ^vk.App {
	app := vk.app_create(
		"devtool",
		"1.0.0",
		"A developer toolkit CLI - JSON, Password, Markdown, and File utilities",
		context.temp_allocator,
	)

	// Setup root with persistent flags and hooks
	setup_root(app.root)

	// Register command groups
	vk.command_add_subcommand(app.root, cmd.make_pass_cmd())
	vk.command_add_subcommand(app.root, cmd.make_json_cmd())
	vk.command_add_subcommand(app.root, cmd.make_md_cmd())
	vk.command_add_subcommand(app.root, cmd.make_file_cmd())
	return app
}

// Setup root command
setup_root :: proc(root: ^vk.Command) {
	// Global verbose flag
	vk.command_add_persistent_flag(root, vk.flag_bool("verbose", "v", "Enable verbose output"))

	// Global hooks
	vk.command_set_persistent_pre_run(root, pre_run)
	vk.command_set_persistent_post_run(root, post_run)
}

pre_run :: proc(ctx: ^vk.Context) -> bool {
	if vk.get_flag_bool(ctx, "verbose") {
		fmt.println("[devtool] Running command...")
	}
	return true
}

post_run :: proc(ctx: ^vk.Context) -> bool {
	if vk.get_flag_bool(ctx, "verbose") {
		fmt.println("[devtool] Done.")
	}
	return true
}
