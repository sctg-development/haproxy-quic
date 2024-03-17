FROM ubuntu:22.04 as builder

RUN apt-get update && \
    apt-get install -y git dpkg-dev debhelper libpcre3-dev zlib1g-dev liblua5.4-dev perl fakeroot

RUN git clone --depth 1 https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./config no-shared && \
    make -j$(nproc) && \
    cd ..

RUN git clone http://git.haproxy.org/git/haproxy-2.9.git/ && \
    cd haproxy-2.9 && \
    make -j$(nproc) V=1 TARGET=linux-glibc USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1 USE_QUIC=1 USE_PROMEX=1 USE_LUA=1 SSL_INC=$(pwd)/../openssl/include SSL_LIB=$(pwd)/../openssl/lib LDFLAGS="-L$(pwd)/../openssl" LIBS="-l:libssl.a -l:libcrypto.a" && \
    fakeroot make install-bin DESTDIR=/tmp/haproxy 

RUN DEPENDS=$(apt-cache depends haproxy | grep Depends | cut -d ":" -f 2 | tr '\n' ',' | sed 's/,$//') && \
    mkdir -p /tmp/haproxy/DEBIAN && \
    echo "Package: haproxy\n\
Version: 2.9\n\
Section: net\n\
Priority: optional\n\
Architecture: $(dpkg --print-architecture)\n\
Depends: liblua5.4-0,$DEPENDS\n\
Maintainer: Maintainer Name <ronan@sctg.eu.org>\n\
Description: HAProxy is a free, very fast and reliable solution offering high availability, load balancing, and proxying for TCP and HTTP-based applications." > /tmp/haproxy/DEBIAN/control

RUN dpkg-deb --build /tmp/haproxy

FROM ubuntu:22.04
COPY --from=builder /tmp/haproxy.deb /haproxy.deb
RUN apt-get update && \
    apt-get install -y liblua5.4-0 /haproxy.deb 
ENTRYPOINT [ "/usr/local/sbin/haproxy" ]