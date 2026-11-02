TWEAK_DIRS := $(patsubst %/Makefile,%,$(wildcard tweaks/*/Makefile))

.PHONY: all clean package

all clean package:
	@set -e; \
	for tweak in $(TWEAK_DIRS); do \
		$(MAKE) -C "$$tweak" $@; \
	done
