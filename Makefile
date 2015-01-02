NAME=mon
SHORTNAME=m
all: version documentation perltidy
version:
	cut -d' ' -f2 debian/changelog | head -n 1 | sed 's/(//;s/)//' > .version
perltidy:
	find . -name \*.pm | xargs perltidy -i 2 -b
	perltidy -b $(NAME)
	find . -name \*.bak -delete
documentation:
	pod2man --release="$(NAME) $$(cat .version)" \
                       --center="User Commands" ./docs/$(NAME).pod > ./docs/$(NAME).1
	pod2text ./docs/$(NAME).pod > ./docs/$(NAME).txt
	gzip -c ./docs/$(NAME).1 > ./docs/$(NAME).1.gz
	cp ./docs/$(NAME).pod ./README.pod
install: deinstall
	test ! -d $(DESTDIR)/usr/bin && mkdir -p $(DESTDIR)/usr/bin || exit 0
	test ! -d $(DESTDIR)/usr/share/$(NAME) && mkdir -p $(DESTDIR)/usr/share/$(NAME) || exit 0
	test ! -d $(DESTDIR)/usr/share/$(NAME)/examples && mkdir -p $(DESTDIR)/usr/share/$(NAME)/examples || exit 0
	test ! -d $(DESTDIR)/usr/share/$(NAME)/contrib && mkdir -p $(DESTDIR)/usr/share/$(NAME)/contrib || exit 0
	test ! -d $(DESTDIR)/usr/share/man/man1 && mkdir -p $(DESTDIR)/usr/share/man/man1 || exit 0
	cp $(NAME) $(DESTDIR)/usr/bin
	cp $(NAME) $(DESTDIR)/usr/bin/$(SHORTNAME)
	cp ./mi $(DESTDIR)/usr/bin
	cp -r ./lib $(DESTDIR)/usr/share/$(NAME)/
	cp ./.version $(DESTDIR)/usr/share/$(NAME)/version
	cp ./$(NAME).conf $(DESTDIR)/usr/share/$(NAME)/examples/$(NAME).conf.sample
	cp ./ca.pem $(DESTDIR)/usr/share/$(NAME)/ca.pem
	cp -R ./contrib/* $(DESTDIR)/usr/share/$(NAME)/contrib
	cp ./docs/$(NAME).1.gz $(DESTDIR)/usr/share/man/man1/$(NAME).1.gz
	test ! -z "$(DESTDIR)" && find $(DESTDIR) -name .\*.swp -delete || exit 0
deinstall:
	test -f $(DESTDIR)/usr/bin/$(NAME) && rm $(DESTDIR)/usr/bin/$(NAME) && rm $(DESTDIR)/usr/bin/$(SHORTNAME) && rm $(DESTDIR)/usr/bin/mi || exit 0
	test -d $(DESTDIR)/usr/share/$(NAME) && rm -r $(DESTDIR)/usr/share/$(NAME) || exit 0
	test -f $(DESTDIR)/usr/share/man/man1/$(NAME).1.gz && rm -f $(DESTDIR)/usr/share/man/man1/$(NAME).1.gz || exit 0
uninstall: deinstall
clean:
	test -d debian/$(NAME)/usr && rm -Rf debian/$(NAME)/usr || exit 0
dch:
	dch -i
deb: 
	dpkg-buildpackage -uc -us
rpm: deb
	alien -r --generate ../$(NAME)_$$(cat ./.version)_all.deb
	cp redhat-specs-add.txt rpm.specs
	sed "s/%%{ARCH}/noarch/" $$(pwd)/$(NAME)-$$(cat ./.version)/*.spec >> rpm.specs
	mv rpm.specs $$(pwd)/$(NAME)-$$(cat ./.version)/*.spec
	rpmbuild --buildroot $$(pwd)/$(NAME)-$$(cat ./.version) -ba $$(pwd)/$(NAME)-$$(cat ./.version)/*.spec
release: dch version 
	git commit -a -m 'New release'
	bash -c "git tag $$(cat .version)"
	git push --tags
	git push origin master
clean-top:
	rm -f ../$(NAME)_*.tar.gz || exit 0
	rm -f ../$(NAME)_*.dsc || exit 0
	rm -f ../$(NAME)_*.changes || exit 0
	rm -f ../$(NAME)_*.deb || exit 0
	rm -f ../$(NAME)-*.rpm || exit 0
dotest:
	sh -c 'cd ./t;make'

