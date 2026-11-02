SUBPROJECTS += $(patsubst %/Makefile,%,$(wildcard tweaks/*/Makefile))

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
