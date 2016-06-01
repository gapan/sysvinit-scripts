
.PHONY: archive
archive:
	git archive --prefix=scripts/ master | xz > ../scripts.tar.xz
