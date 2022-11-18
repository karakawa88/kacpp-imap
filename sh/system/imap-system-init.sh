#!/bin/bash


# ユーザーアカウントの作成
if [[ -r /usr/local/etc/dovecot/users.txt ]]; then
    /usr/local/sh/mail/users_add.sh /usr/local/etc/dovecot/users.txt
fi

sleep 2

systemctl daemon-reload
systemctl enable rsyslog
systemctl enable cron
systemctl enable dovecot

systemctl start rsyslog
systemctl start cron
systemctl start dovecot

exit 0

