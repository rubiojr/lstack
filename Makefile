NAME=lstack
VERSION=$(shell grep ^LSTACK_VERSION lstack.sh | cut -d= -f2)

PKG_DIR=pkg
PKG_NAME=$(NAME)-$(VERSION)
PKG=$(PKG_DIR)/$(PKG_NAME).tar.gz
SIG=$(PKG_DIR)/$(PKG_NAME).asc

PREFIX?=/usr/local
DOC_DIR=$(PREFIX)/share/doc/$(PKG_NAME)

pkg:
	mkdir -p $(PKG_DIR)

$(PKG): pkg
	git archive --output=$(PKG) --prefix=$(PKG_NAME)/ HEAD

$(SIG): $(PKG)
	gpg --sign --detach-sign --armor $(PKG)

build: $(PKG)

clean:
	rm -f $(PKG) $(SIG)