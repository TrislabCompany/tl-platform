# The image every app of a stamp starts on until its first deploy (06 section
# 6.3 in tl-cloud-infrastructure): unprivileged nginx serving one static page
# on port 8080 as a non-root user. The base image is pinned by digest, the
# same as in the app templates.

FROM nginxinc/nginx-unprivileged:1.30.6-alpine@sha256:f5116ed4606f3eb015dd4a8e28cb9b351476dc0ad4bc6e9f93b19cec130cdf03
# Removes what the page never uses, so the image has less to scan and patch:
# curl, and the dynamic modules nginx doesn't load here.
USER root
RUN apk del --no-network curl nginx-module-geoip nginx-module-image-filter nginx-module-njs nginx-module-xslt
USER nginx
COPY default.conf /etc/nginx/conf.d/default.conf
COPY html/ /usr/share/nginx/html/
EXPOSE 8080
