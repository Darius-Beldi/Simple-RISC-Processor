SHELL := /usr/bin/env bash

TOP  ?= tb_top
TIME ?= all
ARGS ?=

.DEFAULT_GOAL := sim

.PHONY: sim batch run_sim gui view clean help

# Compile, elaborate, and run in batch mode. Keep the historical run_sim
# target as an alias so existing course instructions continue to work.
sim batch run_sim:
	@./run.sh --mode batch --top "$(TOP)" --time "$(TIME)" -- $(ARGS)

# Compile and elaborate, then start a live simulator session.
gui:
	@./run.sh --mode gui --top "$(TOP)" -- $(ARGS)

# Open the waveform database produced by the latest batch/GUI run.
view:
	@./run.sh --view

clean:
	@./run.sh --clean

help:
	@./run.sh --help
