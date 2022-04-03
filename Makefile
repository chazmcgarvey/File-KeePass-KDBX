
# This is not a Perl distribution, but it can build one using Dist::Zilla.

CPANM   = cpanm
COVER   = cover
DZIL    = dzil
PROVE   = prove

.PHONY: all bootstrap clean cover dist test

all: dist

bootstrap:
	$(CPANM) Dist::Zilla
	$(DZIL) authordeps --missing |$(CPANM) -nq
	$(DZIL) listdeps --develop --missing |$(CPANM) -nq

clean:
	$(DZIL) $@
	$(RM) -r .smoke

cover:
	$(COVER) -test

dist:
	$(DZIL) build

test:
	$(PROVE) -l $(if $(V),-vj1)

