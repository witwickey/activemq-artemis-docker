# ActiveMQ Artemis

##########################################################
## Build Image                                           #
##########################################################
ARG BASE_IMAGE
FROM openjdk:11.0.14-jre-bullseye as builder
LABEL maintainer="Actively maintained but not actively supported - use at your own risk!"

ARG ACTIVEMQ_ARTEMIS_VERSION
ARG ACTIVEMQ_DISTRIBUTION_URL
ARG BASE_IMAGE
ENV JMX_EXPORTER_VERSION=0.3.1
ENV JGROUPS_KUBERNETES_VERSION=0.9.3
ENV JAVAX_JSON_VERSION=1.1.4

# See https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get -qq -o=Dpkg::Use-Pty=0 update && \
    apt-get -qq -o=Dpkg::Use-Pty=0 install -y --no-install-recommends \
      libaio1=0.3.112-9 \
      xmlstarlet=1.6.1-2.1 \
      jq=1.6-2.1 \
      ivy=2.5.0-1 && \
    rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3008
RUN apt-get -qq -o=Dpkg::Use-Pty=0 update && \
    apt-get -qq -o=Dpkg::Use-Pty=0 install -y --no-install-recommends \
      wget \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Make sure pipes are considered to detemine success, see: https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Uncompress and validate
WORKDIR /opt
RUN if (echo "${ACTIVEMQ_DISTRIBUTION_URL}" | grep -Eq  ".zip\$" ) ; \
    then \
      mkdir -p tmp && \
      wget "${ACTIVEMQ_DISTRIBUTION_URL}" -P tmp/ && \
      unzip -d tmp -q "tmp/*.zip" && rm -f tmp/*.zip && ls -l tmp/ && \
        mv tmp/* ./apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION} && \
        ln -s "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}" "/opt/apache-artemis" && \
        rmdir tmp; \
    elif test -n "${ACTIVEMQ_DISTRIBUTION_URL}" ; \
    then \
      echo "Only .zip format is supported when using ACTIVEMQ_DISTRIBUTION_URL" && \
      exit 2; \
    else \
      wget "https://repository.apache.org/content/repositories/releases/org/apache/activemq/apache-artemis/${ACTIVEMQ_ARTEMIS_VERSION}/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz" \
         "https://repository.apache.org/content/repositories/releases/org/apache/activemq/apache-artemis/${ACTIVEMQ_ARTEMIS_VERSION}/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz.asc" \
         "https://downloads.apache.org/activemq/KEYS" && \
      gpg --no-tty -v --import "KEYS" && \
      gpg --no-tty -v "apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz.asc" && \
      tar xfz "apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz" && \
      ln -s "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}" "/opt/apache-artemis" && \
      rm -f "apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz" "KEYS" "apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz.asc"; \
   fi

# Create broker instance
WORKDIR /var/lib
RUN  "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}/bin/artemis" create artemis \
        --home /opt/apache-artemis \
        --user artemis \
        --password artemis \
        --role amq \
        --require-login \
        --cluster-user artemisCluster \
        --cluster-password artemisretsulc

# Using KUBE_PING 0.9.3. Can't upgrade to 1.x.x as Artemis uses JGroups 3.3.x 
# https://github.com/jgroups-extras/jgroups-kubernetes/issues/30
WORKDIR /opt/jgroupskubernetes
RUN java -jar /usr/share/java/ivy.jar -dependency org.jgroups.kubernetes kubernetes "${JGROUPS_KUBERNETES_VERSION}" -retrieve "[artifact]-[revision](-[classifier]).[ext]" -types jar && \
  java -jar /usr/share/java/ivy.jar -dependency org.jgroups.kubernetes dns "${JGROUPS_KUBERNETES_VERSION}" -retrieve "[artifact]-[revision](-[classifier]).[ext]" -types jar

# JsonFormatter to enable JSON logging #148
WORKDIR /opt/jsonformatter
RUN java -jar /usr/share/java/ivy.jar -dependency org.glassfish javax.json "${JAVAX_JSON_VERSION}" -retrieve "[artifact]-[revision](-[classifier]).[ext]" -types bundle

WORKDIR /var/lib/artemis/etc

# Log to tty to enable docker logs container-name
RUN sed -i "s/logger.handlers=.*/logger.handlers=CONSOLE/g" logging.properties && \
# Add JSON log handler
    echo "formatter.JSON=org.jboss.logmanager.formatters.JsonFormatter" | tee -a  logging.properties && \
    sed -i "s/-Xbootclasspath\/a:\"\(.*\)\"/-Xbootclasspath\/a:\"\1:\/opt\/apache-artemis\/lib\/javax.json-1.1.4.jar\"/g" /var/lib/artemis/bin/artemis && \
    sed -i "s/JAVA_ARGS=\"/JAVA_ARGS=\"-Djava.net.preferIPv4Addresses=true -Djava.net.preferIPv4Stack=true /g" artemis.profile && \
# --java-options doesn't seem to work across the board on all versions adding them manually
    if [ "${BASE_IMAGE}" != "${BASE_IMAGE#openjdk:8}" ]; then \
      sed -i "s/JAVA_ARGS=\"/JAVA_ARGS=\"-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=2 /g" ../etc/artemis.profile; \
    fi && \
# Ports are only exposed with an explicit argument, there is no need to binding
# the web console to localhost. Note in v2.20 the structure changed.
    sed -i 's#//localhost\:#//0.0.0.0:#' bootstrap.xml && \
# In a similar fashion the jolokia access is restricted to localhost only. Disabling
# this as in the natural environmnets for the image like Kubernetes this is problematic.
    sed -i 's#\(<restrict>\)#\1\n  <remote>\n    <host>127.0.0.1</host>\n    <host>localhost</host>\n    <host>10.0.0.0/8</host> \
    <host>172.16.0.0/12</host>\n    <host>192.168.0.0/16</host>\n  </remote>#' jolokia-access.xml && \
# Remove default values for memory in artemis profile in order to let the automatic
# Java ergonomics detection work https://docs.oracle.com/javase/8/docs/technotes/guides/vm/gctuning/ergonomics.html
    sed -i "s/-Xm[xs][^ \"]*//g" artemis.profile && \
# See https://issues.apache.org/jira/browse/ARTEMIS-3616
    if [ "${ACTIVEMQ_ARTEMIS_VERSION}" = "2.20.0" ]; then \
       wget "https://repo1.maven.org/maven2/io/netty/netty-transport-native-unix-common/4.1.72.Final/netty-transport-native-unix-common-4.1.72.Final.jar" && \
       mv netty-transport-native-unix-common-4.1.72.Final.jar ../lib ; \
    fi

WORKDIR /opt/jmx-exporter
RUN wget -v "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar" \
     "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar.sha1" && \
    echo "$(cat "jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar.sha1")" "jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar" | sha1sum -c - && \
    rm "jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar.sha1" && \
    ln -s "/opt/jmx-exporter/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar" "/opt/jmx-exporter/jmx_prometheus_javaagent.jar"

COPY assets/jmx-exporter-config.yaml /opt/jmx-exporter/etc/

##########################################################
## Run Image                                             #
##########################################################
# hadolint ignore=DL3006
FROM $BASE_IMAGE
LABEL maintainer="Actively maintained but not actively supported - use at your own risk!"
ARG ACTIVEMQ_ARTEMIS_VERSION
ARG BASE_IMAGE
ENV ACTIVEMQ_ARTEMIS_VERSION=$ACTIVEMQ_ARTEMIS_VERSION
ENV BASE_IMAGE=$BASE_IMAGE

# add user and group for artemis
# hadolint ignore=DL3009
RUN groupadd -g 1000 -r artemis && useradd -r -u 1000 -g artemis artemis && \
    apt-get -qq -o=Dpkg::Use-Pty=0 update && \
    apt-get -qq -o=Dpkg::Use-Pty=0 remove curl -y && \
    if [ "${BASE_IMAGE}" != "${BASE_IMAGE%stretch}" ]; then \
      apt-get -qq -o=Dpkg::Use-Pty=0 install -y --no-install-recommends \
          libaio1=0.3.110-3 \
          xmlstarlet=1.6.1-2 \
          jq=1.5+dfsg-1.3 \
          gettext-base=0.19.8.1-2+deb9u1 \
          dumb-init=1.2.0-1 \
          procps=2:3.3.12-3+deb9u1 ; \
    elif [ "${BASE_IMAGE}" != "${BASE_IMAGE%buster}" ]; then \
      apt-get -qq -o=Dpkg::Use-Pty=0 install -y --no-install-recommends \
          libaio1=0.3.112-3 \
          xmlstarlet=1.6.1-2 \
          jq=1.5+dfsg-2+b1 \
          gettext-base=0.19.8.1-9 \
          dumb-init=1.2.2-1.1 \
          procps=2:3.3.15-2 ; \
    elif [ "${BASE_IMAGE}" != "${BASE_IMAGE%bullseye}" ]; then \
      apt-get -qq -o=Dpkg::Use-Pty=0 install -y --no-install-recommends \
          libaio1=0.3.112-9 \
          xmlstarlet=1.6.1-2.1 \
          jq=1.6-2.1 \
          gettext-base=0.21-4 \
          dumb-init=1.2.5-1 \
          procps=2:3.3.17-5 ; \
    else \
      echo "Only bullseye or buster or stretch supported as base image" && \
      exit 2; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3008
RUN apt-get -qq -o=Dpkg::Use-Pty=0 update && \
    apt-get -qq -o=Dpkg::Use-Pty=0 install -y --no-install-recommends \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}" "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}"
COPY --from=builder "/var/lib/artemis" "/var/lib/artemis"
COPY --from=builder "/opt/jmx-exporter" "/opt/jmx-exporter"
COPY --from=builder "/opt/jgroupskubernetes/*" "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}/lib/"
COPY --from=builder "/opt/jsonformatter/*" "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}/lib/"

# To enable RESTORE_CONFIGURATION
COPY --from=builder "/var/lib/artemis/etc" "/var/lib/artemis/etc-backup"

RUN ln -s "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}" /opt/apache-artemis && chmod 755 /opt/apache-artemis && \
    chown -R artemis.artemis /var/lib/artemis && \
    chown -R artemis.artemis /opt/jmx-exporter && \
    mkdir -p /opt/assets

COPY assets/merge.xslt /opt/assets
COPY assets/enable-jmx.xml /opt/assets
COPY assets/semver2.sh /usr/local/bin/semver

# Web Server
EXPOSE 8161

# JMX Exporter
EXPOSE 9404

# Port for CORE,MQTT,AMQP,HORNETQ,STOMP,OPENWIRE
EXPOSE 61616

# Port for HORNETQ,STOMP
EXPOSE 5445

# Port for AMQP
EXPOSE 5672

# Port for MQTT
EXPOSE 1883

#Port for STOMP
EXPOSE 61613

WORKDIR /var/lib/artemis/bin

USER artemis

RUN mkdir /var/lib/artemis/lock

# Expose some outstanding folders
VOLUME ["/var/lib/artemis/data"]
VOLUME ["/var/lib/artemis/tmp"]
VOLUME ["/var/lib/artemis/etc"]
VOLUME ["/var/lib/artemis/etc-override"]
VOLUME ["/var/lib/artemis/lock"]
VOLUME ["/opt/jmx-exporter/etc-override"]

COPY assets/docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["artemis-server"]
