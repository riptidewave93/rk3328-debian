.DEFAULT_GOAL := build

setup:
	sudo modprobe loop; \
	sudo modprobe binfmt_misc

build: setup
	@set -e;	\
	for file in `ls ./scripts/[0-99]*.sh`;	\
	do					\
		bash $${file};			\
	done					\

clean:
	sudo rm -rf $(CURDIR)/BuildEnv; \
	docker ps -a | awk '{ print $$1,$$2 }' | grep rk3588-debian:builder | awk '{print $$1 }' | xargs -I {} docker rm {};

distclean: clean
	docker rmi rk3588-debian:builder -f; \
	rm -rf $(CURDIR)/downloads $(CURDIR)/output

mountclean:
	sudo umount $(CURDIR)/BuildEnv/rootfs/boot; \
	sudo umount $(CURDIR)/BuildEnv/rootfs; \
	sudo losetup -D