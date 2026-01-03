.PHONY: build-example run-example clean test check lint

BUILD_DIR := build

all: clean test check lint build-example run-example
	@echo "All done"

build-example:
	@echo "Building example..."
	@mkdir -p $(BUILD_DIR)
	@odin build examples/mycli -out:$(BUILD_DIR)/mycli

run-example: build-example
	@echo "Running example..."
	@./$(BUILD_DIR)/mycli --version

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)

test:
	@echo "Testing..."
	@mkdir -p $(BUILD_DIR)
	@odin test valkyrie -out:$(BUILD_DIR)/test

check:
	@echo "Checking..."
	@mkdir -p $(BUILD_DIR)
	@odin build valkyrie -build-mode:obj -out:$(BUILD_DIR)/valkyrie.o
	@odin check examples/mycli

lint:
	@echo "Linting..."
	@mkdir -p $(BUILD_DIR)
	@odin build valkyrie -build-mode:obj -vet -out:$(BUILD_DIR)/valkyrie_lint.o
	@odin build examples/mycli -vet -out:$(BUILD_DIR)/mycli_lint
