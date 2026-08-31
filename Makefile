# Developer and release entry points for the qluent Claude Code plugin.
#
# `test` globs tests/*.sh on purpose: a test file that exists but that no CI
# step names is a test nobody runs, and that is exactly how coverage rots.

.PHONY: help test version-check cli-floor bump release

.DEFAULT_GOAL := help

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

test: ## Run every contract test in tests/
	@failed=0; \
	for t in tests/*.sh; do \
		printf '==> %s\n' "$$t"; \
		if ! bash "$$t"; then failed=1; printf 'FAILED: %s\n' "$$t"; fi; \
	done; \
	if [ "$$failed" -ne 0 ]; then echo; echo 'Some tests failed.'; exit 1; fi; \
	echo; echo 'All tests passed.'

version-check: ## Verify every manifest agrees on one version
	node scripts/bump-version.mjs --check

cli-floor: ## Verify the required qluent CLI version is published to npm
	bash scripts/check-cli-floor.sh

bump: ## Bump every manifest to VERSION (make bump VERSION=0.5.0)
	@test -n "$(VERSION)" || (echo 'Error: VERSION is required, e.g. make bump VERSION=0.5.0'; exit 1)
	node scripts/bump-version.mjs $(VERSION)

release: ## Tag and push VERSION, cutting the GitHub release
	@test -n "$(VERSION)" || (echo 'Error: VERSION is required, e.g. make release VERSION=0.5.0'; exit 1)
	@test -z "$$(git status --porcelain)" || (echo 'Error: working tree is dirty; commit the version bump first'; exit 1)
	@test "$$(git rev-parse --abbrev-ref HEAD)" = main || (echo 'Error: release from main'; exit 1)
	@git fetch -q origin main && test -z "$$(git rev-list HEAD..origin/main)" \
		|| (echo 'Error: local main is behind origin/main; pull first'; exit 1)
	node scripts/bump-version.mjs --check $(VERSION)
	$(MAKE) cli-floor
	$(MAKE) test
	git tag -a v$(VERSION) -m 'Release plugin $(VERSION)'
	git push origin v$(VERSION)
	@echo
	@echo 'Pushed v$(VERSION). CI now cuts the GitHub release.'

