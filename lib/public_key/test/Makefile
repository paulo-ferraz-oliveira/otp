#
# %CopyrightBegin%
#
# SPDX-License-Identifier: Apache-2.0
#
# Copyright Ericsson AB 2008-2025. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# %CopyrightEnd%
#

include $(ERL_TOP)/make/target.mk
include $(ERL_TOP)/make/$(TARGET)/otp.mk


INCLUDES= -I. -I ../include -pa $(ERL_TOP)/lib/public_key/ebin

# ----------------------------------------------------
# Target Specs
# ----------------------------------------------------

MODULES= \
	erl_make_certs \
	public_key_SUITE \
	pbe_SUITE \
	pkits_SUITE \
	pubkey_cert_SUITE \
	pubkey_policy_tree_SUITE \
	pubkey_ocsp_SUITE

ERL_FILES= $(MODULES:%=%.erl)

HRL_FILES= 

TARGET_FILES= \
	$(MODULES:%=$(EBIN)/%.$(EMULATOR))

SPEC_FILES = public_key.spec

COVER_FILE = public_key.cover


# ----------------------------------------------------
# Release directory specification
# ----------------------------------------------------
RELSYSDIR = $(RELEASE_PATH)/public_key_test

# ----------------------------------------------------
# FLAGS
# ----------------------------------------------------
ERL_COMPILE_FLAGS += $(INCLUDES) +nowarn_missing_spec_documented
ERL_COMPILE_FLAGS := $(filter-out +deterministic,$(ERL_COMPILE_FLAGS))

EBIN = .

# ----------------------------------------------------
# Targets
# ----------------------------------------------------

tests $(TYPES): $(TARGET_FILES)


clean:
	rm -f $(TARGET_FILES)
	rm -f core

docs:

# ----------------------------------------------------
# Release Target
# ---------------------------------------------------- 
include $(ERL_TOP)/make/otp_release_targets.mk

release_spec: opt

release_tests_spec: opt
	$(INSTALL_DIR) "$(RELSYSDIR)"
	$(INSTALL_DATA) $(SPEC_FILES) $(ERL_FILES) $(COVER_FILE) $(HRL_FILES) "$(RELSYSDIR)"
	$(INSTALL_DATA) $(TARGET_FILES) "$(RELSYSDIR)"
	chmod -R u+w "$(RELSYSDIR)"
	@tar cf - *_SUITE_data | (cd "$(RELSYSDIR)"; tar xf -)
release_docs_spec:


