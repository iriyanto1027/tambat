# Maintainer tasks. Nothing here is needed to use a topology: `./tambat` and
# plain `docker compose` both work without make.
#
# Kept compatible with GNU Make 3.81 (the default on macOS): no .ONESHELL,
# no $(file ...), no other 4.x features.

# Absolute path to this repository, so `make -C` and `make -f` also work.
REPO_ROOT := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help

.PHONY: help lint

help:
	@echo "tambat maintainer tasks:"
	@echo "  make lint    shellcheck every shell file, validate every topology's compose.yaml"

lint:
	@"$(REPO_ROOT)scripts/lint.sh"
