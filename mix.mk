MIX_DEPS_PATH ?= $(DEPS_DIR)/.mix/
MIX_ENV ?= prod

DEPS += elixir_repo
NO_AUTOPATCH += elixir_repo
dep_elixir_repo ?= git https://github.com/elixir-lang/elixir.git v1.14.4

$(eval $(call dep_target,elixir_repo))

export MIX_DEPS_PATH
export MIX_ENV

define add_app
$(eval $(info adding $(1) at $(2)))
$(eval dep_$(1) = ln $(2))
$(eval DEPS = $(1) $(DEPS))
$(eval NO_AUTOPATCH += $(1))
$(eval $(call dep_target,$(1)))
$(eval $(shell $(call dep_fetch_ln,$(1))))
$(eval $(shell echo $(2) >> $(ERLANG_MK_TMP)/deps.log))
$(eval ELIXIR_APPS += $(1))
endef

define elixir_app
$(DEPS_DIR)/elixir_repo/lib/$(1)/ebin:: $(DEPS_DIR)/elixir_repo
	$(dep_verbose) $(MAKE) -C $(DEPS_DIR)/elixir_repo/ compile

$(DEPS_DIR)/elixir_repo/lib/$(1)/ebin/dep_built:: $(DEPS_DIR)/elixir_repo/lib/$(1)/ebin
	$(dep_verbose) touch $(DEPS_DIR)/elixir_repo/lib/$(1)/ebin/dep_built
endef

.PHONY: compile-elixir

compile-elixir: $(DEPS_DIR)/elixir_repo
compile-elixir: $(foreach app,$(notdir $(wildcard $(DEPS_DIR)/elixir_repo/lib/*)),$(eval $(call elixir_app,$(app)) $(call add_app,$(app),$(DEPS_DIR)/elixir_repo/lib/$(app))))
compile-elixir: $(foreach app,$(value ELIXIR_APPS),$(DEPS_DIR)/elixir_repo/lib/$(app)/ebin/dep_built)
compile-elixir: $(foreach app,$(value ELIXIR_APPS),$(DEPS_DIR)/$(call dep_name,$1))
compile-elixir:
	$(dep_verbose) $(foreach app,$(value ELIXIR_APPS),$(call dep_autopatch_noop,$(app));)

define hex.mk
DEPS_DIR ?= $$(CURDIR)/../

ERL=erl -noshell $(foreach app,$(ELIXIR_APPS),-pa $$(DEPS_DIR)/$(app)/ebin/)

comma=,

MIX_DEPS_PATH ?= $$(DEPS_DIR)
MIX_ENV ?= prod

MIX=$$(ERL) -eval 'application:ensure_all_started(mix).' \\
	-eval 'application:ensure_all_started(logger).' \\
	-eval "'Elixir.Mix.CLI':main(tl([undefined $$(foreach word,$$(1),$(comma)<<\"$$(word)\">>)]))."

compile: local.hex deps
	@$$(call MIX,compile) -eval 'init:stop().'
	@cd $$(CURDIR)/_build/$$(MIX_ENV)/lib/; for lib in *; do \\
		if test -d "$$$$lib"; then \\
			ln -sf $$(CURDIR)/_build/$$(MIX_ENV)/lib/$$$$lib/ebin $$(DEPS_DIR)/$$$$lib/ebin; \\
		else \\
			ln -sf $$(CURDIR)/_build/$$(MIX_ENV)/lib/$$$$lib $$(DEPS_DIR)/; \\
		fi; \\
	done;

deps: local.hex
	@$$(call MIX,deps.get) -eval 'init:stop().'
	@$$(call MIX,deps.compile) -eval 'init:stop().'

local.hex:
	@$$(call MIX,local.hex --force --if-missing) -eval 'init:stop().'
endef

define NEWLINE


endef

define ESCAPE
$(subst $$,$$$$,$(subst $$,\$$,$(subst ",\",$(subst $(NEWLINE),\n,$(subst \,\\,$(1))))))
endef

define autopatch_mix
ifneq ($(wildcard $(DEPS_DIR)/$(1)/mix.exs),)
.PHONY: autopatch-$(1)
autopatch-$(1):: $(DEPS_DIR)/elixir_repo/lib/mix/ebin
	$(verbose) if ! test -f $(DEPS_DIR)/$(1)/Makefile || make -q -C $(DEPS_DIR)/$(1) noop 2>&1 1>/dev/null; then \
		echo 'Needs Makefile: $(1)' >&2; \
		echo "$(call ESCAPE,$(call hex.mk))" > $(DEPS_DIR)/$(1)/Makefile; \
	fi;
endif
endef

$(foreach dep,$(DEPS),$(eval $(call autopatch_mix,$(dep))))
