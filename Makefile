# Author : Connor Beeney
# Date   : 9th of July, 2025

# common params
CAT                := cat
MKDIR              := mkdir -p
RESOURCE           := Resource/
TEMP               := Temp/
BUILD_DIR          := Build/
LOG                := Log/
CP                 := cp -fr
RM                 := rm -rf
THIS			   := "$(shell pwd)/Makefile"
LOCK			   := Lock/
TARGET             := hello-world

# host params
DOCKER                := docker
DOCKER_BUILD          := $(DOCKER) build
DOCKER_RUN            := $(DOCKER) run
BASE_IMAGE            := alpine:3.22
BUILD_CONTAINER_LABEL := ginix-builder-image
LOG_CONTAINER_LABEL   := ginix-log-image
RUN_CONTAINER_LABEL   := ginix-run-image
MAKEFILE_HELP         := Makefile-help.txt
DOCKERFILE            := dockerfile
EXTERNAL_DIR          := External
DEPENDENCY            := Dependency

# container params
PACKAGE_MANAGER    := apk
PACKAGE_INSTALL    := $(PACKAGE_MANAGER) add
PACKAGES           := make gcc g++
RUNTIME_PACKAGES   := make
PACKAGES_UPGRADE   := $(PACKAGE_MANAGER) update && $(PACKAGE_MANAGER) upgrade
CC                 := gcc
CXX				   := g++
LD                 := gcc
LDFLAGS            ?= -static
SOURCE_DIR         := Source/
OBJECT_DIR		   := Object/
CFLAGS			   := -Wall -Wextra -O3 -Ofast -g -Os -s
C_SOURCES		   ?= $(wildcard $(SOURCE_DIR)/*.c)
OBJECTS            ?= $(patsubst $(SOURCE_DIR)/%.c, $(OBJECT_DIR)/%.c.o, $(C_SOURCES))

default: display-help

display-help:
	@ $(CAT) $(RESOURCE)$(MAKEFILE_HELP) && echo
	
# host build rules

host:                          \
    host-prepare               \
	host-build-dockerimage     \
	host-log-dockerimage       \
	host-run-log-dockerimage   \
	host-run-build-dockerimage \
	host-finalise

host-prepare:              \
    $(BUILD_DIR)           \
	$(TEMP)$(RESOURCE)     \
	$(TEMP)$(BUILD_DIR)    \
	$(TEMP)$(OBJECT_DIR)   \
	$(TEMP)$(SOURCE_DIR)   \
	$(TEMP)$(EXTERNAL_DIR) \
	$(TEMP)$(DEPENDENCY)   \
	$(TEMP)$(THIS)         \
	$(TEMP)$(LOCK)

host-build-dockerimage:
	$(shell test -f $(TEMP)$(LOCK)$(BUILD_CONTAINER_LABEL) || touch $(TEMP)$(LOCK)$(BUILD_CONTAINER_LABEL) &&  \
	$(DOCKER_BUILD) $(TEMP) -t $(BUILD_CONTAINER_LABEL) -f $(TEMP)$(RESOURCE)$(DOCKERFILE)/$(DOCKERFILE)-build \
		--build-arg HOSTARG_BASEIMAGE="$(BASE_IMAGE)"                                                          \
		--build-arg HOSTARG_INSTALL_PACKAGES_COMMAND="$(PACKAGE_INSTALL) $(PACKAGES)"                          \
 		--build-arg HOSTARG_PACKAGES_UPGRADE="$(PACKAGES_UPGRADE)"                                             \
	)

host-run-build-dockerimage:
	$(DOCKER_RUN) --mount type=bind,source="$(abspath $(TEMP))",target=/project/ $(BUILD_CONTAINER_LABEL)

host-clean:
	$(RM) "$(TEMP)" "$(BUILD_DIR)" "$(LOG)"

host-log:
	$(DOCKER_RUN) $(LOG_CONTAINER_LABEL)

host-log-dockerimage:
	$(DOCKER_BUILD) "$(TEMP)" -t $(LOG_CONTAINER_LABEL) -f "$(TEMP)$(RESOURCE)$(DOCKERFILE)/$(DOCKERFILE)-log" --build-arg HOSTARG_BASEIMAGE=$(BASE_IMAGE)

host-run-log-dockerimage:
	$(DOCKER_RUN) $(LOG_CONTAINER_LABEL)

host-finalise:
	$(CP) $(wildcard $(TEMP)$(BUILD_DIR)/*) $(BUILD_DIR)
	chown -R $$SUDO_USER:$$SUDO_USER "$(BUILD_DIR)" "$(TEMP)"

host-run: \
	host  \
	host-build-run-dockerimage \
	host-run-run-dockerimage

host-build-run-dockerimage:
	$(DOCKER_BUILD) $(BUILD_DIR) -t $(RUN_CONTAINER_LABEL) -f "$(TEMP)$(RESOURCE)$(DOCKERFILE)/$(DOCKERFILE)-run" \
		--build-arg HOSTARG_BASEIMAGE="$(BASE_IMAGE)"                                                         \
		--build-arg HOSTARG_INSTALL_RUNTIME_PACKAGES_COMMAND="$(PACKAGE_INSTALL) $(RUNTIME_PACKAGES)"                         \
		--build-arg HOSTARG_PACKAGES_UPGRADE="$(PACKAGES_UPGRADE)"

host-run-run-dockerimage:
	$(DOCKER_RUN) --mount type=bind,source="$(abspath $(BUILD_DIR))",target=/project/ \
				  --mount type=bind,source=$(THIS),target=/project/Makefile \
				   $(RUN_CONTAINER_LABEL)

# container build rules

container:                   \
	container-prepare        \
	container-build

container-prepare:

container-build: $(OBJECTS)
	$(LD) $(OBJECTS) -o $(BUILD_DIR)$(TARGET) $(LDFLAGS)

container-log:
	@ echo "Build environment variables:"
	@ echo "CC: $(CC)"
	@ echo "CXX: $(CXX)"
	@ echo "LD: $(LD)"
	@ echo "CFLAGS: $(CFLAGS)"
	@ echo "OBJECTS: $(OBJECTS)"
	@ echo "C_SOURCES: $(C_SOURCES)"
	@ echo "THIS: $(THIS)"
	@ echo "BUILD_DIR: $(BUILD_DIR)"
	@ echo "SOURCE_DIR: $(SOURCE_DIR)"
	@ echo "OBJECT_DIR: $(OBJECT_DIR)"
	@ echo "TEMP: $(TEMP)"
	@ echo "RESOURCE: $(RESOURCE)"
	@ echo "BASE_IMAGE: $(BASE_IMAGE)"
	@ echo "BUILD_CONTAINER_LABEL: $(BUILD_CONTAINER_LABEL)"
	@ echo "DOCKERFILE: $(DOCKERFILE)"
	@ echo "PACKAGE_MANAGER: $(PACKAGE_MANAGER)"
	@ echo "PACKAGE_INSTALL: $(PACKAGE_INSTALL)"
	@ echo "PACKAGES: $(PACKAGES)"
	@ echo "MAKEFILE_HELP: $(MAKEFILE_HELP)"

container-run:
	./$(TARGET)

$(OBJECT_DIR)/%.c.o: $(SOURCE_DIR)/%.c $(OBJECT_DIR)
	$(CC) -c $< -o $@ $(CFLAGS)

$(OBJECT_DIR):
	$(MKDIR) $(OBJECT_DIR)

$(BUILD_DIR):
	$(MKDIR) $(BUILD_DIR)

$(TEMP)$(RESOURCE): $(wildcard $(RESOURCE)/*)
	$(MKDIR) $(TEMP)$(RESOURCE)
	$(CP) $(wildcard $(RESOURCE)/*) $(TEMP)$(RESOURCE)

$(TEMP)$(BUILD_DIR): $(TEMP) $(BUILD_DIR)
	$(MKDIR) $(TEMP)$(BUILD_DIR)

$(TEMP)$(OBJECT_DIR): $(TEMP) $(OBJECT_DIR)
	$(MKDIR) $(TEMP)$(OBJECT_DIR)

$(TEMP)$(SOURCE_DIR): $(TEMP) $(wildcard $(SOURCE_DIR)/*)
	$(MKDIR) $(TEMP)$(SOURCE_DIR)
	$(CP) $(wildcard $(SOURCE_DIR)/*) $(TEMP)$(SOURCE_DIR)

$(TEMP)$(EXTERNAL_DIR): $(TEMP) $(EXTERNAL_DIR)
	$(MKDIR) $(TEMP)$(EXTERNAL_DIR)

$(TEMP)$(THIS): $(TEMP)
	$(CP) $(THIS) "$(TEMP)$(shell basename $(THIS))"

$(TEMP)$(DEPENDENCY): $(TEMP) $(DEPENDENCY)
	$(MKDIR) $(TEMP)$(DEPENDENCY)

$(TEMP)$(LOCK): $(TEMP)
	$(MKDIR) $(TEMP)$(LOCK)
# misc build rules

$(TEMP):
	$(MKDIR) $(TEMP)
	chown -R $SUDO_USER:$SUDO_USER $(TEMP)

# alias'
build: host
clean: host-clean
run: host-run
log: host-log

# extra