FROM nginx:stable-alpine

ENV NGINX_APP=/app/nginx
ENV NGINX_TEMPLATE=/etc/nginx/templates/default.conf.template

COPY nginx.conf $NGINX_TEMPLATE
# COPY --from=build /app/build /usr/share/nginx/html

WORKDIR /app

COPY custom.sh app.sh

RUN chmod +x ./app.sh
RUN ./app.sh $NGINX_APP $NGINX_APP/nginx.conf $NGINX_TEMPLATE
