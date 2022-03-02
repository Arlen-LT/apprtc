#######DEMO APP, DO NOT USE THIS FOR ANYTHING BUT TESTING PURPOSES, ITS NOT MEANT FOR PRODUCTION######

FROM golang:1.17.5-alpine3.15

# Install and download deps.
RUN apk add --no-cache git curl python2 build-base openssl-dev openssl \
    && git clone https://github.com/Arlen-LT/apprtc.git \
# AppRTC GAE setup
# Required to run GAE dev_appserver.py.
    && curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-367.0.0-linux-x86_64.tar.gz --output gcloud.tar.gz \
    && tar -xf gcloud.tar.gz \
    && google-cloud-sdk/bin/gcloud components install app-engine-python-extras app-engine-python cloud-datastore-emulator --quiet \
    && rm -f gcloud.tar.gz \
# Mimick build step by manually copying everything into the appropriate folder and run build script.
    && python apprtc/build/build_app_engine_package.py apprtc/src/ apprtc/out/ \
    && curl https://webrtc.github.io/adapter/adapter-latest.js --output apprtc/src/web_app/js/adapter.js \
    && cp apprtc/src/web_app/js/*.js apprtc/out/js/ \
# Collider setup
# Go environment setup.
    && export GOPATH=$HOME/goWorkspace/ \
    && go env -w GO111MODULE=off

RUN ln -s `pwd`/apprtc/src/collider/collidermain $GOPATH/src \
    && ln -s `pwd`/apprtc/src/collider/collidertest $GOPATH/src \
    && ln -s `pwd`/apprtc/src/collider/collider $GOPATH/src \
    && cd $GOPATH/src \
    && go get collidermain \
    && go install collidermain
    
ENV STUNNEL_VERSION 5.60
WORKDIR /usr/src
RUN curl  https://www.stunnel.org/archive/5.x/stunnel-${STUNNEL_VERSION}.tar.gz --output stunnel.tar.gz\
    && tar -xf /usr/src/stunnel.tar.gz
WORKDIR /usr/src/stunnel-${STUNNEL_VERSION}
RUN ./configure --prefix=/usr && make && make install \
    && echo -e "foreground=yes\n" > /usr/etc/stunnel/stunnel.conf \
    && echo -e "[AppRTC GAE]\n" >> /usr/etc/stunnel/stunnel.conf \ 
    && echo -e "accept=0.0.0.0:443\n" >> /usr/etc/stunnel/stunnel.conf \
    && echo -e "connect=0.0.0.0:8080\n" >> /usr/etc/stunnel/stunnel.conf \
    && echo -e "cert=/cert/cert.pem\n" >> /usr/etc/stunnel/stunnel.conf 
    
RUN echo -e  "/go/google-cloud-sdk/bin/dev_appserver.py --host 0.0.0.0 apprtc/out/app.yaml --enable_host_checking=false --ssl_certificate_path /cert/cert.pem --ssl_certificate_key_path /cert/key.pem &\n" >> /go/start.sh \ 
    && echo -e "/go/src/bin/collidermain -tls=false -port=8089 -room-server=http://localhost &\n" >> /go/start.sh \
    && echo -e  "/usr/bin/stunnel &\n" >> /go/start.sh \
    && echo -e "wait -n\n" >> /go/start.sh \
    && echo -e "exit $?\n" >> /go/start.sh \
    && chmod +x /go/start.sh

# Start the bash wrapper that keeps both collider and the AppRTC GAE app running. 
CMD /go/start.sh

## Instructions (Tested on Debian 11 only):
# - Download the Dockerfile from the AppRTC repo and put it in a folder, e.g. 'apprtc'
# - Build the Dockerfile into an image: 'sudo docker build apprtc/'
#   Note the image ID from the build command, e.g. something like 'Successfully built 503621f4f7bd'.
# - Run: 'sudo docker run -p 443:443 -p 8089:8089 --rm -ti 503621f4f7bd'
#   The container will now run in interactive mode and output logging. If you do not want this, omit the '-ti' argument.
#   The '-p' options are port mappings to the GAE app and Collider instances, the host ones can be changed.
#
# - On the same machine that this docker image is running on you can now join apprtc calls using 
#   https://localhost/?wshpp=localhost:8089&wstls=true,  once you join the URL will have 
#   appended the room name which you can share, e.g. 'http://localhost:8080/r/315402015?wshpp=localhost:8089&wstls=true'. 
#   If you want to connect to this instance from another machine, use the IP address of the machine running this docker container 
#   instead of localhost.
#   
#   Keep in mind that you need to pass in those 'wshpp' and 'wstls' URL parameters everytime you join with as they override 
#   the websocket server address.
#
# The steps assume sudo is required for docker, that can be avoided but is out of scope.

## TODO
# Verify if this docker container run on more OS's?
