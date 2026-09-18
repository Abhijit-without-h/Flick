.PHONY: build test app run install icons dist

icons:
	bash Scripts/build-icons.sh

build:
	swift build

test:
	swift run FlickSelfTest

app:
	bash Scripts/package-app.sh

run: app
	open dist/Flick.app

install: app
	rm -rf /Applications/Flick.app
	cp -R dist/Flick.app /Applications/Flick.app
	open /Applications/Flick.app

dist:
	bash Scripts/make-dist.sh
