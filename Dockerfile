FROM alpine:edge

RUN apk update \
 && apk add --no-cache samba \
 && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* \
 \
 && touch /var/lib/samba/registry.tdb \
 && touch /var/lib/samba/account_policy.tdb

VOLUME ["/shares"]

EXPOSE 139 445

COPY scripts /usr/local/bin/

HEALTHCHECK CMD ["docker-healthcheck.sh"]
ENTRYPOINT ["entrypoint.sh"]

CMD [ "sh", "-c", "smbd --no-process-group -FS -d 2 < /dev/null" ]
