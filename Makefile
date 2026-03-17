BINARY      = bigclock
INSTALL_DIR = $(HOME)/.local/bin
PLIST_LABEL = com.$(shell whoami).bigclock
PLIST_DIR   = $(HOME)/Library/LaunchAgents
PLIST_FILE  = $(PLIST_DIR)/$(PLIST_LABEL).plist

# Optional CLI args baked into the launchd job, e.g.:
#   make install ARGS="--time-format HH:mm --font-size 80"
ARGS ?=

define PLIST_CONTENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$(PLIST_LABEL)</string>
	<key>ProgramArguments</key>
	<array>
		<string>$(INSTALL_DIR)/$(BINARY)</string>
		$(foreach arg,$(ARGS),<string>$(arg)</string>)
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
</dict>
</plist>
endef
export PLIST_CONTENT

.PHONY: build install uninstall

build:
	swift build -c release

install: build
	mkdir -p $(INSTALL_DIR)
	cp .build/release/$(BINARY) $(INSTALL_DIR)/$(BINARY)
	mkdir -p $(PLIST_DIR)
	-launchctl unload $(PLIST_FILE) 2>/dev/null; true
	echo "$$PLIST_CONTENT" > $(PLIST_FILE)
	launchctl load $(PLIST_FILE)
	@echo "Installed and started. Logs: log stream --predicate 'process == \"$(BINARY)\"'"

uninstall:
	-launchctl unload $(PLIST_FILE)
	rm -f $(PLIST_FILE)
	rm -f $(INSTALL_DIR)/$(BINARY)
	@echo "Uninstalled."
