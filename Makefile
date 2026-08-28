.PHONY: install-hooks lint test

install-hooks:
	./scripts/install-hooks.sh

test:
	./tests/integration.sh
	./tests/smoke-hooks.sh

lint:
	./tests/lint.sh
