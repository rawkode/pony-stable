prefix ?= /usr/local
destdir ?= ${prefix}
config ?= release

BUILD_DIR ?= build/$(config)
SRC_DIR ?= stable
binary := $(BUILD_DIR)/stable

ifdef config
  ifeq (,$(filter $(config),debug release))
    $(error Unknown configuration "$(config)")
  endif
endif

ifeq ($(config),release)
	PONYC = ponyc
else
	PONYC = ponyc --debug
endif

SOURCE_FILES := $(shell find $(SRC_DIR) -name \*.pony)

$(binary): $(SOURCE_FILES) | $(BUILD_DIR)
	${PONYC} $(SRC_DIR) -o ${BUILD_DIR}

install: $(binary)
	mkdir -p $(prefix)/bin
	cp $^ $(prefix)/bin

test: $(binary)

clean:
	rm -rf $(BUILD_DIR)

all: $(binary)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

ifneq ($(wildcard .git),)
  tag := $(shell cat VERSION)-$(shell git rev-parse --short HEAD)
else
  tag := $(shell cat VERSION)
endif

# package_name, _version, and _iteration can be overridden by Travis or AppVeyor
package_base_version ?= $(tag)
package_iteration ?= "1"
package_name ?= "pony-stable"
package_version = $(package_base_version)-$(package_iteration)
archive = $(package_name)-$(package_version).tar
package = build/$(package_name)-$(package_version)

# Note: linux only
define EXPAND_DEPLOY
deploy: test
	$(SILENT)bash .bintray.bash debian "$(package_version)" "$(package_name)"
	$(SILENT)bash .bintray.bash rpm    "$(package_version)" "$(package_name)"
	$(SILENT)bash .bintray.bash source "$(package_version)" "$(package_name)"
	$(SILENT)rm -rf build/bin
	@mkdir -p build/bin
	@mkdir -p $(package)/usr/bin
	@mkdir -p $(package)/usr/lib/pony-stable/$(package_version)/bin

	$(SILENT)cp $(BUILD_DIR)/stable $(package)/usr/lib/pony-stable/$(package_version)/bin

	$(SILENT)ln -f -s /usr/lib/pony-stable/$(package_version)/bin/stable $(package)/usr/bin/stable
	$(SILENT)fpm -s dir -t deb -C $(package) -p build/bin --name $(package_name) --conflicts "pony-stable-master" --conflicts "pony-stable-release" --version $(package_base_version) --iteration "$(package_iteration)" --description "Pony dependency manager" --provides "stable" --provides "pony-stable-release"
	$(SILENT)fpm -s dir -t rpm -C $(package) -p build/bin --name $(package_name) --conflicts "pony-stable-master" --conflicts "pony-stable-release" --version $(package_base_version) --iteration "$(package_iteration)" --description "Pony dependency manager" --provides "stable" --provides "pony-stable-release"
	$(SILENT)git archive HEAD > build/bin/$(archive)
	$(SILENT)bzip2 build/bin/$(archive)
	$(SILENT)rm -rf $(package) build/bin/$(archive)
endef

$(eval $(call EXPAND_DEPLOY))

.PHONY: all clean deploy install
