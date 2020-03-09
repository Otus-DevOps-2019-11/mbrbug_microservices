FROM grafana/grafana:5.0.0

#RUN mkdir /var/lib/grafana/dashboards
COPY dashboards /etc/grafana/dashboards
COPY provisioning/datasources /etc/grafana/provisioning/datasources
COPY provisioning/dashboards /etc/grafana/provisioning/dashboards
