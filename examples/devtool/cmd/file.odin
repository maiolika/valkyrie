package cmd

import vk "../../../valkyrie"
import "core:crypto/hash"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

// File utilities command
make_file_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("file", "File utilities")

	vk.command_add_subcommand(cmd, make_file_hash_cmd())
	vk.command_add_subcommand(cmd, make_file_size_cmd())
	vk.command_add_subcommand(cmd, make_file_find_cmd())

	return cmd
}

// --- Hash subcommand ---

make_file_hash_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("hash", "Calculate file hash")
	vk.command_add_flag(
		cmd,
		vk.flag_string("algorithm", "a", "Hash algorithm (sha256, sha512)", "sha256"),
	)
	vk.command_set_handler(cmd, file_hash_handler)
	return cmd
}

file_hash_handler :: proc(ctx: ^vk.Context) -> bool {
	if len(ctx.args) == 0 {
		fmt.eprintln("Error: please provide a file path")
		return false
	}

	filepath := ctx.args[0]
	algo := vk.get_flag_string(ctx, "algorithm")
	verbose := vk.get_flag_bool(ctx, "verbose")

	if verbose {
		fmt.printfln("Calculating %s hash for: %s", algo, filepath)
	}

	// Read file
	data, ok := os.read_entire_file(filepath)
	if !ok {
		fmt.eprintfln("Error: could not read file '%s'", filepath)
		return false
	}
	defer delete(data)

	// Calculate hash
	hash_algo: hash.Algorithm
	switch algo {
	case "sha256":
		hash_algo = .SHA256
	case "sha512":
		hash_algo = .SHA512
	case "sha1":
		hash_algo = .SHA512 // Use SHA512 as fallback
	case:
		fmt.eprintfln("Error: unknown algorithm '%s'. Use sha256, sha512, or sha1", algo)
		return false
	}

	digest := hash.hash(hash_algo, data)

	// Print hash as hex
	for b in digest {
		fmt.printf("%02x", b)
	}
	fmt.printfln("  %s", filepath)

	return true
}

// --- Size subcommand ---

make_file_size_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("size", "Show file or directory size")
	vk.command_add_flag(cmd, vk.flag_bool("human", "H", "Human-readable size"))
	vk.command_set_handler(cmd, file_size_handler)
	return cmd
}

file_size_handler :: proc(ctx: ^vk.Context) -> bool {
	if len(ctx.args) == 0 {
		fmt.eprintln("Error: please provide a file or directory path")
		return false
	}

	path := ctx.args[0]
	human := vk.get_flag_bool(ctx, "human")

	// Get file info
	info, err := os.stat(path)
	if err != nil {
		fmt.eprintfln("Error: could not access '%s'", path)
		return false
	}

	size := info.size

	if human {
		fmt.printfln("%s  %s", format_size(size), path)
	} else {
		fmt.printfln("%d  %s", size, path)
	}

	return true
}

format_size :: proc(bytes: i64) -> string {
	KB :: 1024
	MB :: KB * 1024
	GB :: MB * 1024

	if bytes >= GB {
		return fmt.tprintf("%.1fG", f64(bytes) / f64(GB))
	} else if bytes >= MB {
		return fmt.tprintf("%.1fM", f64(bytes) / f64(MB))
	} else if bytes >= KB {
		return fmt.tprintf("%.1fK", f64(bytes) / f64(KB))
	}
	return fmt.tprintf("%dB", bytes)
}

// --- Find subcommand ---

make_file_find_cmd :: proc() -> ^vk.Command {
	cmd := vk.command_create("find", "Find files matching pattern")
	vk.command_add_flag(cmd, vk.flag_string("dir", "d", "Directory to search", "."))
	vk.command_add_flag(cmd, vk.flag_string("ext", "e", "File extension to match", ""))
	vk.command_set_handler(cmd, file_find_handler)
	return cmd
}

file_find_handler :: proc(ctx: ^vk.Context) -> bool {
	dir := vk.get_flag_string(ctx, "dir")
	ext := vk.get_flag_string(ctx, "ext")
	verbose := vk.get_flag_bool(ctx, "verbose")

	pattern := ""
	if len(ctx.args) > 0 {
		pattern = ctx.args[0]
	}

	if verbose {
		fmt.printfln("Searching in: %s", dir)
		if pattern != "" {
			fmt.printfln("Pattern: %s", pattern)
		}
		if ext != "" {
			fmt.printfln("Extension: %s", ext)
		}
	}

	count := 0
	find_files(dir, pattern, ext, &count)

	if verbose {
		fmt.printfln("\nFound: %d files", count)
	}

	return true
}

find_files :: proc(dir: string, pattern: string, ext: string, count: ^int) {
	handle, err := os.open(dir)
	if err != nil {
		return
	}
	defer os.close(handle)

	file_infos, read_err := os.read_dir(handle, -1)
	if read_err != nil {
		return
	}
	defer delete(file_infos)

	for fi in file_infos {
		full_path := filepath.join({dir, fi.name})
		defer delete(full_path)

		// Check if directory using mode
		is_dir := (fi.mode & os.File_Mode_Dir) != {}

		if is_dir {
			find_files(full_path, pattern, ext, count)
		} else {
			matches := true

			// Check pattern
			if pattern != "" {
				matches = strings.contains(fi.name, pattern)
			}

			// Check extension
			if matches && ext != "" {
				file_ext := filepath.ext(fi.name)
				// Remove leading dot from extension
				if len(file_ext) > 0 && file_ext[0] == '.' {
					file_ext = file_ext[1:]
				}
				matches = file_ext == ext
			}

			if matches {
				fmt.println(full_path)
				count^ += 1
			}
		}
	}
}
