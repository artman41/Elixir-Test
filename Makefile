PROJECT = elixir_test
PROJECT_DESCRIPTION = New project
PROJECT_VERSION = 0.1.0

#DEPS += elixir_repo
DEPS += jason
#NO_AUTOPATCH += elixir_repo

#dep_elixir_repo = git https://github.com/elixir-lang/elixir.git v1.14.4
dep_jason = git https://github.com/michalmuskala/jason.git v1.4.0

deps:: compile-elixir

BUILD_DEPS += relx
include erlang.mk
include mix.mk