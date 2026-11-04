.PHONY: build app

build:
	swift build --disable-sandbox

app:
	bash scripts/build-app.sh

.PHONY: test
test:
	bash scripts/test.sh
