package cmd

import vk "../../../valkyrie"
import "core:fmt"
import "core:math/rand"
import "core:strings"

// Password generator command
make_pass_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("pass", "Password generation utilities")
	vk.command_add_alias(cmd, "password")

	vk.command_add_subcommand(cmd, make_pass_gen_cmd())

	return cmd
}

// --- Generate subcommand ---

make_pass_gen_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("gen", "Generate a secure password")
	vk.command_add_alias(cmd, "generate")

	vk.command_add_flag(cmd, vk.flag_int("length", "l", "Password length", 16))
	vk.command_add_flag(cmd, vk.flag_int("count", "c", "Number of passwords to generate", 1))
	vk.command_add_flag(cmd, vk.flag_bool("no-symbols", "S", "Exclude symbols"))
	vk.command_add_flag(cmd, vk.flag_bool("no-numbers", "N", "Exclude numbers"))
	vk.command_add_flag(cmd, vk.flag_bool("no-uppercase", "U", "Exclude uppercase letters"))

	vk.command_set_handler(cmd, pass_gen_handler)
	return cmd
}

pass_gen_handler :: proc(ctx: ^vk.Context) -> bool {
	length := vk.get_flag_int(ctx, "length")
	count := vk.get_flag_int(ctx, "count")
	no_symbols := vk.get_flag_bool(ctx, "no-symbols")
	no_numbers := vk.get_flag_bool(ctx, "no-numbers")
	no_uppercase := vk.get_flag_bool(ctx, "no-uppercase")
	verbose := vk.get_flag_bool(ctx, "verbose")

	if length < 4 {
		fmt.eprintln("Error: password length must be at least 4")
		return false
	}

	if length > 128 {
		fmt.eprintln("Error: password length cannot exceed 128")
		return false
	}

	if count < 1 || count > 100 {
		fmt.eprintln("Error: count must be between 1 and 100")
		return false
	}

	// Build character set
	charset := strings.builder_make()
	defer strings.builder_destroy(&charset)

	strings.write_string(&charset, "abcdefghijklmnopqrstuvwxyz")
	if !no_uppercase {
		strings.write_string(&charset, "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
	}
	if !no_numbers {
		strings.write_string(&charset, "0123456789")
	}
	if !no_symbols {
		strings.write_string(&charset, "!@#$%^&*()_+-=[]{}|;:,.<>?")
	}

	chars := strings.to_string(charset)

	if verbose {
		fmt.printfln("Generating %d password(s) of length %d", count, length)
	}

	for _ in 0 ..< count {
		password := generate_password(chars, length)
		fmt.println(password)
		delete(password)
	}

	return true
}

generate_password :: proc(charset: string, length: int) -> string {
	result := make([]u8, length)
	for i := 0; i < length; i += 1 {
		idx := rand.int_max(len(charset))
		result[i] = charset[idx]
	}
	return string(result)
}
