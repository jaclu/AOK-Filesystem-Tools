#
# 	idev_ip is used to detect ip# on iSH-AOK kernels
# 	This Makefile can not have an install clause, since
# 	depending on it being compiled
#	for Alpine the resulting bin should go to combined/usr_local_bin/alpine-idev_ip
#	for Debian/Devuan the resulting bin should go to combined/usr_local_bin/famdeb-idev_ip
#	So in order to deploy the bin, you need to compile it on the
#	desired distro, then making sure the bin is picked up at the right
#	location by the git-repo
#
all: idev_ip

clean:
	rm idev_ip

idev_ip: idev_ip.c
	gcc -o idev_ip idev_ip.c

install_alpine:  all
	cp idev_ip ../combined/usr_local_bin/alpine-idev_ip

install_debian:  all
	cp idev_ip ../combined/usr_local_bin/famdeb-idev_ip
