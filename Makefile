.POSIX:

include config.mk

all:

install:
	$(error UNIMPLEMENTED)

uninstall:
	$(error UNIMPLEMENTED)

install_bashcomp:
	$(error UNIMPLEMENTED)
	mkdir -p ${DESTDIR}${BASHCOMPDIR}
	cp -f bash_completion ${DESTDIR}${BASHCOMPDIR}/jukebox

uninstall_bashcomp:
	$(error UNIMPLEMENTED)
	rm -f ${DESTDIR}${BASHCOMPDIR}/jukebox

clean:
	rm -f ${DIST}.tar.gz

dist: clean
	git archive --format=tar.gz -o ${DIST}.tar.gz --prefix=${DIST}/ HEAD

.PHONY: all install uninstall install_bashcomp uninstall_bashcomp clean dist
