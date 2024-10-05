FROM debian:12

EXPOSE 80
EXPOSE 443

ENV NZBGET_MainDir /nzbget
ENV NZBGET_DestDir '${MainDir}/storage'
ENV NZBGET_NzbDir '${MainDir}/nzb'
ENV NZBGET_QueueDir '${MainDir}/nzb/queue'
ENV NZBGET_TempDir '${MainDir}/nzb/tmp'
ENV NZBGET_ScriptDir '${MainDir}/scripts'
ENV NZBGET_LogFile '${MainDir}/nzb/logs/nzbget.log'
ENV NZBGET_LockFile '${MainDir}/nzb/nzbget.lock'
ENV NZBGET_CertStore /etc/ssl/certs/ca-certificates.crt
ENV NZBGET_ControlIP 0.0.0.0
ENV NZBGET_ControlPort 80
ENV NZBGET_SecureControl yes
ENV NZBGET_SecurePort 443
ENV NZBGET_SecureCert /etc/ssl/certs/nzbget/nzbget.crt
ENV NZBGET_SecureKey /etc/ssl/certs/nzbget/private/nzbget.key
ENV NZBGET_ControlUsername ''
ENV NZBBET_ControlPassword ''

ENV SHOW_CONFIG false

RUN apt-get update && apt-get install -y nzbget unrar-free unzip p7zip par2 uudeview openssl ca-certificates && apt-get clean
RUN mkdir -p -m 775 /nzbget/storage && mkdir -p -m 775 /nzbget/nzb

COPY entrypoint.sh /entrypoint.sh

VOLUME /nzbget
VOLUME /nzbget/nzb

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nzbget","-s"]
