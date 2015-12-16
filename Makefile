VERSION = 0.4
DISTNAME = wowcamldebug
DISTDIR = $(DISTNAME)-$(VERSION)
DISTSTUFF = \
	bitmaps/ *.ml *.mli *.c *.vim Makefile Makefile.conf \
	CHANGES COPYING LICENSE README INSTALL
OCAMLFIND = ocamlfind
OCAMLC = $(OCAMLFIND) ocamlc -package pcre,unix
CFLAGS += -Wall
DEBUG =
include Makefile.conf
all: wowcamldebug wowtell
wowcamldebug: wow_unix.o wowUnix.cmo wowcamldebug.ml
	$(OCAMLC) $(DEBUG) -custom -o $@ -linkpkg $^
wowtell: wowtell.ml
	$(OCAMLC) $(DEBUG) -o $@ -linkpkg $<
wowUnix.cmo: wowUnix.ml wowUnix.cmi
	$(OCAMLC) $(DEBUG) -c $<
wowUnix.cmi: wowUnix.mli
	$(OCAMLC) -c $<
wow_test: wow_test.ml
	$(OCAMLC) -g -o $@ -linkpkg $<
test: wow_test wowcamldebug
	./wowcamldebug $<
dist:
	rm -rf $(DISTDIR)
	mkdir $(DISTDIR)
	cp -a $(DISTSTUFF) $(DISTDIR)/
	tar cvzf $(DISTDIR).tar.gz $(DISTDIR)
	rm -rf $(DISTDIR)
clean:
	rm -f \
		*.cm[aiox] *.cmxa *.[ao] *.so \
		wowcamldebug wowtell test
install: all
	test -d $(VIMDIR) || mkdir -p $(VIMDIR)
	test -d $(DESTDIR) || mkdir -p $(DESTDIR)
	cp -a bitmaps/ wowcamldebug.vim $(VIMDIR)/
	cp -a wowcamldebug wowtell $(DESTDIR)/
.PHONY: all clean dist install test
