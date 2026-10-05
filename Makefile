# Priism autobuild. `make config`, then `sudo make autobuild`.
# (or copy config.mk.example to config.mk and set SHIM_DIR by hand)
-include config.mk
SHIM_DIR ?=

config:
	@while true; do \
		echo "Where are your shims located? (absolute path, no quotes)"; \
		printf "> "; \
		read choice; \
		if [ -d "$$choice" ]; then \
			printf 'SHIM_DIR = %s\n' "$$choice" > config.mk; \
			echo "Saved. Run \`sudo make autobuild\` to start building."; \
			break; \
		else \
			echo "Invalid directory."; \
		fi; \
	done

autobuild:
	@if [ "$$(id -u)" -ne 0 ]; then echo "Please run as root."; exit 1; fi
	@if [ -z "$(SHIM_DIR)" ]; then echo "SHIM_DIR not set. Run \`make config\` first."; exit 1; fi
	@if [ ! -d "$(SHIM_DIR)" ]; then echo "Invalid directory: $(SHIM_DIR)"; exit 1; fi
	@for f in "$(SHIM_DIR)"/*; do \
		echo "Building $$f"; \
		bash priism_builder.sh "$$f" || exit 1; \
	done

.PHONY: autobuild config
