DOCKER_IMAGE ?= esbmc-shedskin

.PHONY: docker-build docker-shell docker-run-example

docker-build:
	docker build -t $(DOCKER_IMAGE) .

docker-shell: docker-build
	docker run --rm -it -v "$(PWD)":/workspace -w /workspace $(DOCKER_IMAGE)

# Smoke: convert, compile, and run the Shedskin runtime example inside Docker
docker-run-example: docker-build
	docker run --rm -it -v "$(PWD)":/workspace -w /workspace $(DOCKER_IMAGE) \
		-lc "set -e; rm -rf /tmp/shedskin-smoke; mkdir -p /tmp/shedskin-smoke; cp -r /workspace/examples /tmp/shedskin-smoke/; cd /tmp/shedskin-smoke/examples; exec bash"
