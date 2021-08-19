# Copyright (c) 2017, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

NV_WINSYS = egldevice


CFLAGS   = $(NV_PLATFORM_OPT)     $(NV_PLATFORM_CFLAGS)
CPPFLAGS = $(NV_PLATFORM_SDK_INC) $(NV_PLATFORM_CPPFLAGS)
LDFLAGS  = $(NV_PLATFORM_SDK_LIB) $(NV_PLATFORM_LDFLAGS)

NV_PLATFORM_OPT       = -Os
NV_PLATFORM_CFLAGS    = -O2 \
			-fomit-frame-pointer \
			-finline-functions \
			-finline-limit=300 \
			-fgcse-after-reload

#Append common cflags
NV_PLATFORM_CFLAGS   += -fno-strict-aliasing \
			-Wall \
			-Wcast-align

NV_PLATFORM_CPPFLAGS  = -DNV_GLES_VER_MAJOR=2 -DWIN_INTERFACE_CUSTOM

NV_PLATFORM_LDFLAGS   = -Wl,--dynamic-linker=/lib/ld-linux-aarch64.so.1 \
			-L${ROOTFS}/usr/lib/aarch64-linux-gnu/tegra-egl \
			-L${ROOTFS}/usr/lib/aarch64-linux-gnu/tegra \
			-L$(TOOLCHAIN_DIR)/../aarch64-unknown-linux-gnu/sysroot/usr/lib \
			-L${ROOTFS}/usr/lib/aarch64-linux-gnu \
			-Wl,-rpath-link=$(ROOTFS)/usr/lib/aarch64-linux-gnu/tegra-egl \
			-Wl,-rpath-link=$(ROOTFS)/usr/lib/aarch64-linux-gnu/tegra \
			-Wl,-rpath-link=$(ROOTFS)/usr/lib/aarch64-linux-gnu \
			-Wl,-rpath-link=$(ROOTFS)/lib/aarch64-linux-gnu

NV_PLATFORM_SDK_INC_DIR = ../include
NV_PLATFORM_NVGL_INC_DIR = ../nvgldemo
NV_PLATFORM_GEAR_INC_DIR = ../gears-lib
NV_PLATFORM_TEXFONT_INC_DIR = ../nvtexfont

NV_PLATFORM_SDK_INC   = -I$(NV_PLATFORM_SDK_INC_DIR) \
			-I$(NV_PLATFORM_NVGL_INC_DIR) \
			-I$(NV_PLATFORM_TEXFONT_INC_DIR) \
			-I$(NV_PLATFORM_GEAR_INC_DIR)

NV_PLATFORM_SDK_LIB   = -L$(NV_PLATFORM_SDK_LIB_DIR) \
			-L$(NV_PLATFORM_SDK_LIB_DIR)/$(NV_WINSYS) \
			-Wl,-rpath-link=$(NV_PLATFORM_SDK_LIB_DIR) \
			-Wl,-rpath-link=$(NV_PLATFORM_SDK_LIB_DIR)/$(NV_WINSYS)

NV_PLATFORM_MATHLIB   = -lm
NV_PLATFORM_THREADLIB = -lpthread

CC     = ${TOOLCHAIN_PREFIX}gcc
CXX    = ${TOOLCHAIN_PREFIX}g++
AR     = ${TOOLCHAIN_PREFIX}ar
ifeq ($(LD),ld)
LD = $(if $(wildcard *.cpp),$(CXX),$(CC))
endif
#RANLIB, STRIP, NM are empty by default
RANLIB ?= ${TOOLCHAIN_PREFIX}ranlib
STRIP  ?= ${TOOLCHAIN_PREFIX}strip
NM     ?= ${TOOLCHAIN_PREFIX}nm

$(warning using CC      = $(CC))
$(warning using CXX     = $(CXX))
$(warning using AR      = $(AR))
$(warning using LD      = $(LD))
$(warning using RANLIB  = $(RANLIB))
$(warning using STRIP   = $(STRIP))
$(warning using NM      = $(NM))
$(warning If this is not intended please unset and re-make)

STRINGIFY = /bin/sed -e 's|\"|\\\"|g;s|^.*$$|"&\\n"|'

%.glslvh: %.glslv
	/bin/cat $(filter %.h,$^) $(filter %.glslv,$^) | \
	$(STRINGIFY) > $@

%.glslfh: %.glslf
	/bin/cat $(filter %.h,$^) $(filter %.glslf,$^) | \
	$(STRINGIFY) > $@

# support for windowing system subdirs

NV_LIST_WINSYS :=  egldevice wayland x11
ifndef NV_WINSYS
NV_WINSYS := x11
ifneq ($(NV_WINSYS),$(NV_LIST_WINSYS))
$(warning Defaulting NV_WINSYS to x11; legal values are: $(NV_LIST_WINSYS))
endif
endif

ifeq ($(NV_WINSYS),egldevice)
NV_PLATFORM_CPPFLAGS +=
NV_PLATFORM_WINSYS_LIBS = -ldl
NV_PLATFORM_SDK_INC += -I$(DRM_INC)
else ifeq ($(NV_WINSYS),wayland)
NV_PLATFORM_CPPFLAGS += -DWAYLAND
NV_PLATFORM_SDK_INC += -I$(WAYLAND_INC) \
                       -I$(XKBCOMMON_INC) \
                       -I"$(TARGET_ROOTFS)/usr/include/libdrm"
NV_PLATFORM_WINSYS_LIBS = \
		-l:libxkbcommon.so.0 -l:libwayland-client.so.0 -l:libwayland-egl.so.1 -l:libffi.so.6 -l:libnvbuf_utils.so -l:libweston-6.so.0 -l:libweston-desktop-6.so.0 -l:fullscreen-shell.so
else ifeq ($(NV_WINSYS),x11)
NV_PLATFORM_CPPFLAGS += -DX11
NV_PLATFORM_SDK_INC  += -I$(X11_INC)
NV_PLATFORM_WINSYS_LIBS = -l:libX11.so.6 -l:libXau.so.6
else
$(error Invalid NV_WINSYS value: $(NV_WINSYS))
endif

$(NV_WINSYS)/%.o : %.c
	@mkdir -p $(NV_WINSYS)
	$(COMPILE.c) $(OUTPUT_OPTION) $<

$(NV_WINSYS)/%.o : %.cpp
	@mkdir -p $(NV_WINSYS)
	$(COMPILE.cpp) $(OUTPUT_OPTION) $<

# By default we use the following options
#   - Use native functions for window and operating system interaction
#   - Use source shaders
#   - Build shaders into the application rather than using external data files
# Any of these can be overridden with environment variables or by
#   modifying this file. Note that demo executables must be build with the
#   same settings as the demo libraries they link against.
# If you choose external shader files, you will need to copy the files
#   (.cgbin for binary, .glsl[fv] for source) to the platform along with
#   the executable.
NV_USE_BINARY_SHADERS ?= 0
NV_USE_EXTERN_SHADERS ?= 0

ifeq ($(NV_USE_BINARY_SHADERS),1)
CPPFLAGS += -DUSE_BINARY_SHADERS
endif
ifeq ($(NV_USE_EXTERN_SHADERS),1)
CPPFLAGS += -DUSE_EXTERN_SHADERS
endif




















#include ../Makefile.l4tsdkdefs
TARGETS += $(NV_WINSYS)/gears


GEARS_OBJS :=
GEARS_OBJS += $(NV_WINSYS)/gears.o

INTERMEDIATES += $(GEARS_OBJS)


GEARS_LDLIBS :=
GEARS_LDLIBS += -lm
GEARS_LDLIBS += -lrt
GEARS_LDLIBS += -lpthread
GEARS_LDLIBS += -lEGL
GEARS_LDLIBS += -l:libGLESv2.so.2
GEARS_LDLIBS += -ldl
#GEARS_LDLIBS += ${NV_PLATFORM_WINSYS_LIBS}

ifeq ($(findstring $(NV_WINSYS),egldevice screen wayland x11),)
all:
	echo Sample not supported for NV_WINSYS=
else
all: $(TARGETS)
endif

clean:
	rm -rf $(TARGETS) $(INTERMEDIATES)

.PHONY: FORCE
FORCE:

$(NV_WINSYS)/gears: $(GEARS_OBJS) 
	$(LD) $(LDFLAGS) -o $@ $^ $(GEARS_LDLIBS)

define demolib-rule
$(1): FORCE
	$(MAKE) -C $$(subst $$(NV_WINSYS)/,,$$(dir $$@))
endef

