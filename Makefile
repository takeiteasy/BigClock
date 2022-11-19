bigclock: bigclock.m
	 clang bigclock.m -framework Cocoa -o bigclock

app: bigclock
	sh appify.sh -s bigclock -n BigClock

clean:
	rm bigclock

install: app
	mv -f BigClock.app /Applications

default: app
all: default

.PHONY: bigclock app clean install default all
