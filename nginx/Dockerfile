FROM ndtao2020/nginx-modules:mainline-alpine

# Create dir for customs
RUN mkdir -p /etc/nginx/ssl/ && \
    chmod -R 755 /etc/nginx/ssl/
RUN mkdir -p /etc/nginx/custom/ && \
    chmod -R 755 /etc/nginx/custom/

COPY conf/custom/* /etc/nginx/custom
# COPY conf/template.conf /etc/nginx/templates/default.conf.template
COPY conf/templates/* /etc/nginx/templates/

# openssl dhparam -out ./dhparams.pem 2048
COPY conf/dhparams.pem /etc/nginx/ssl/dhparams.pem
COPY conf/nginx.conf /etc/nginx/nginx.conf

RUN chown -R nginx:nginx /etc/nginx/ && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx

RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid /run/nginx.pid

# docker exec -it nginx /bin/sh
USER nginx
