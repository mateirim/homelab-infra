FROM docker.io/grafana/promtail
RUN apt update
RUN apt install syslog-ng -y
EXPOSE 1514
EXPOSE 514
ADD 1-network.conf /etc/syslog-ng/conf.d
RUN mkdir /var/log/networklogs
# RUN apt install netcat -y
RUN apt install telnet  -y
USER 0
RUN echo 'SYSLOGNG_OPTS="--no-caps"' >> /etc/default/syslog-ng
RUN service syslog-ng start
ENTRYPOINT ["/bin/sh", "-c", "syslog-ng && /usr/bin/promtail -config.file=/etc/promtail/promtail.yaml"]
