.PHONY: help bootstrap build model verify start stop smoke ansible-check ansible-apply ab perf-apply

help:
	@echo "glimmerlocal targets:"
	@echo "  make bootstrap   # deps + dirs + env"
	@echo "  make build       # llama.cpp CUDA (pinned)"
	@echo "  make model       # download GGUF + checksums"
	@echo "  make verify      # sha256 only"
	@echo "  make start|stop|smoke"
	@echo "  make ab          # A/B performance matrix"
	@echo "  make perf-apply  # apply selected perf-q3 profile"
	@echo "  make ansible-check|ansible-apply"

bootstrap:
	./scripts/bootstrap.sh

build:
	./scripts/build-llama-cpp.sh

model:
	./scripts/download-model.sh

verify:
	./scripts/verify-checksums.sh

start:
	./scripts/start-server.sh

stop:
	./scripts/stop-server.sh

smoke:
	./scripts/smoke-test.sh

ab:
	./scripts/run-ab-matrix.sh

perf-apply:
	./scripts/apply-perf-q3.sh

ansible-check:
	cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check

ansible-apply:
	cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/site.yml
