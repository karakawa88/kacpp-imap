# IMAP/POPサーバーdovecot環境を持つdebianイメージ
# 日本語化も設定済み
FROM        kagalpandh/kacpp-gccdev AS builder
SHELL       [ "/bin/bash", "-c" ]
WORKDIR     /root
ENV         DEBIAN_FORONTEND=noninteractive
# dovecot環境変数
# dovecot download URL: https://dovecot.org/releases/2.3/dovecot-2.3.14.tar.gz
ENV         DOVECOT_VERSION=2.3.19
ENV         DOVECOT_SRC=dovecot-${DOVECOT_VERSION}
ENV         DOVECOT_SRC_FILE=${DOVECOT_SRC}.tar.gz
ENV         DOVECOT_URL="https://dovecot.org/releases/2.3/${DOVECOT_SRC_FILE}"
ENV         DOVECOT_DEST=${DOVECOT_SRC}
COPY        sh/apt-install/imap-dev.txt /usr/local/sh/apt-install
# https://github.com/cyrusimap/cyrus-sasl/archive/refs/tags/cyrus-sasl-2.1.27.zip
# 開発環境インストール
RUN         apt update && \
            /usr/local/sh/system/apt-install.sh install gccdev.txt && \
            /usr/local/sh/system/apt-install.sh install imap-dev.txt && \
            # msmtpビルド
            # ./configure --prefix=... && make && make install
            wget ${DOVECOT_URL} && tar -zxvf ${DOVECOT_SRC_FILE} && cd ${DOVECOT_SRC} && \
                ./configure --prefix=/usr/local/${DOVECOT_DEST} --with-sql=yes --with-pgsql && \
                make && make install
# クリーンアップ
RUN         apt autoremove -y && apt clean && rm -rf /var/lib/apt/lists/*
FROM        kagalpandh/kacpp-pydev
SHELL       [ "/bin/bash", "-c" ]
WORKDIR     /root
USER        root
EXPOSE      110 143 993 995
VOLUME      ["/home/mail_users", "/usr/local/etc"]
# rsyslog用環境変数
ENV         SYSLOG_GID=110
ENV         SYSLOG_UID=104
# OpenDMARC環境変数
ENV         DOVECOT_VERSION=2.3.19
ENV         DOVECOT_SRC=dovecot-${DOVECOT_VERSION}
ENV         DOVECOT_DEST=${DOVECOT_SRC}
ENV         DOVECOT_UID=996
ENV         DOVECOT_GID=995
ENV         DOVECOT_USER=dovecot
ENV         DOVECOT_GROUP=dovecot
COPY        --from=builder /usr/local/${DOVECOT_DEST}/ /usr/local
#パッケージのインストールを先に行う
# 設定ファイルのコピーの先にやらないと上書きされるかエラーでビルドできない
# COPY        --from=builder /usr/local/var/spool/postfix/ /var/spool/postfix
COPY        sh/  /usr/local/sh
# COPY        supervisord.conf /root
# COPY        .msmtprc /root
# https://letsencrypt.org/certs/lets-encrypt-r3-cross-signed.pem
RUN         apt update && \
            # rsyslog
            # rsyalogはパッケージで入れるがその場合は先にグループ・ユーザーが作成され
            # UID, GIDが指定できなくなるので先にrsyslogグループユーザーの作成
            groupadd -g ${SYSLOG_GID} syslog && \
                useradd -u ${SYSLOG_UID} -s /bin/false -d /dev/null -g syslog -G syslog syslog && \
                chown -R root.syslog /var/log && chmod 3775 /var/log && \
            mkdir /var/log/mail && chown root.mail /var/log/mail && chmod 3775 /var/log/mail && \
            chown root.mail /home/mail_users && \
                chmod 3775 /home/mail_users && \
            # 必要なパッケージのインストール
            /usr/local/sh/system/apt-install.sh install imap.txt && \
            # dovecotの配置と設定
            # dovecotユーザー・グループ作成
            groupadd -g ${DOVECOT_GID} ${DOVECOT_GROUP} && \
                useradd -u ${DOVECOT_UID} -s /bin/false -d /dev/null -g ${DOVECOT_GROUP} \
                    -G "${DOVECOT_GROUP}" ${DOVECOT_USER} && \
                # なぜかdovecotのライブラリは/usr/local/lib/dovecotにあり
                # 起動の時ライブラリを読み込めないので手動で設定
                echo "/usr/local/lib/dovecot" >>/etc/ld.so.conf && ldconfig && \
                # プログラムが/usr/local/dovecot-xxxx/binのプログラムを参照しているためリンクでごまかす
                ln -s /usr/local /usr/local/${DOVECOT_DEST} && \
            #systemdの設定
            # ENTRYPOINTとクリーンアップ
            chmod 775 /usr/local/sh/system/*.sh && \
            chmod 775 /usr/local/sh/mail/*.sh && \
            # クリーンアップ
            apt clean && rm -rf /var/lib/apt/lists/*
# systemdやcron.dなどの設定ファイルはパッケージインストールの後に行うようにする
# それによって上書きやエラーでビルドできないことを避けるため
COPY        etc/systemd/system/  /etc/systemd/system/
COPY        etc/logrotate.d/    /etc/logrotate.d
COPY        etc/cron.d/    /etc/cron.d
COPY        etc/rsyslog.conf /etc
COPY        etc/rsyslog.d/ /etc/rsyslog.d
# 設定ファイルのパーミッションと所有者の設定
# logrotateとcron
RUN         chown -R root.root /etc/logrotate.d && chmod 644 /etc/logrotate.d/* && \
            chown -R root.root /etc/cron.d && chmod 644 /etc/cron.d/*
ENTRYPOINT  ["/usr/local/sh/system/imap-system.sh"]
