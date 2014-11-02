NAME=lstack
VERSION=$(shell grep ^LSTACK_VERSION lstack | cut -d= -f2)

PKG_DIR=pkg
PKG_NAME=$(NAME)-$(VERSION)
PKG=$(PKG_DIR)/$(PKG_NAME).tar.gz
SIG=$(PKG_DIR)/$(PKG_NAME).asc
DEB_TARGET_DIR=$(HOME)/debian/$(NAME)
BATS="./vendor/bats/bin/bats"

PREFIX?=/usr/local
DOC_DIR=$(PREFIX)/share/doc/$(PKG_NAME)

pkg:
	mkdir -p $(PKG_DIR)

$(PKG): pkg
	git archive --output=$(PKG) --prefix=$(PKG_NAME)/ HEAD

deborig: $(PKG)
	mv $(PKG) ../$(NAME)_$(VERSION).orig.tar.gz

$(SIG): $(PKG)
	gpg --sign --detach-sign --armor $(PKG)

build: $(PKG)

clean:
	rm -rf $(PKG_DIR)
	rm -f $(SIG)

debpkg: deborig
	mkdir -p $(DEB_TARGET_DIR)
	debuild -S && mv ../$(NAME)_* $(DEB_TARGET_DIR)

test:
	$(BATS) test/bootstrap.bat test/ip.bat

.PHONY: test
