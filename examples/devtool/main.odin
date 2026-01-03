package main

import vk "../../valkyrie"
import "core:os"

main :: proc() {
	app := make_app()
	os.exit(vk.app_run(app))
}
