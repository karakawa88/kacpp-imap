# kagalpandh/kacpp-imap IMAP/POP受信メールサーバー環境Dockerイメージ

## 概要
IMAP/POPメール受信サーバー環境Dockerイメージ。
IMAP/POP受信サーバーにdovecotを使用している。
メールのログをシステムログに送るためrsyslogを使用しており
そのため複数のサーバーを立ち上げることによりsystemdを使用している。

## IMAP/POP受信サーバー
受信サーバーはdovecotを使用している。
設定ファイルのディレクトリは/usr/local/etc/dovecotで/usr/local/etcを外側から
マウントすることにより設定ファイルを用意する。
メールアカウントのホームディレクトリは外側に用意し/home/mail_usersにマウントする。
ログはrsyslogのmailファシリティを使用しデフォルトでは/var/log/mail.logに出力される。
環境変数MAIL_LOG_HOSTにホスト名を指定するとそのホストにログを転送できる。
その場合転送されるホストのrsyslogをサーバーモードでTCPでログを受信できるように設定する。

## メールユーザーの追加
メールユーザーは/usr/local/sh/mailのusers_add.shシェルスクリプトで簡単に追加できる。
このシェルスクリプトは引数か/usr/local/etc/usrs.txtからユーザー情報を読み込みユーザー追加を行う。
このファイルをコンテナー起動前など上のディレクトリにusers.txtとして配置すれば自動で追加できる。
既存のシステムにメールユーザーを追加する場合はこのファイルにユーザー情報を追記しておけばよい。
users.txtの書式
ユーザー名:パスワード:ユーザーID
このシェルスクリプトが作成するユーザーのshellは/bin/shでグループはmailで固定される。
このシェルスクリプトのユーザーのホームディレクトリは/home/mail_users/ユーザー名であり
このシェルスクリプトではコンテナ側にホームディレクトリを作成しない。
そのためあらかじめユーザーをホスト側で用意し/home/mail_usersをマウントすることが推奨される。
ちなみに手動でコンテナ側にユーザーのホームディレクトリを用意することもできる。


## dovecotのユーザーグループ
またサービスが使用するユーザー・グループはホストとUIDとGIDを合わせる必要がある。
UIDとGIDの対応 ユーザー.グループの書式
dovecot
~~~
ユーザー   dovecot       996
グループ    dovecot     995
~~~

## マウント
設定ファイルの格納場所/usr/local/etcとメールユーザーのホームディレクトリの場所/home/mail_usersはマウントする必要がある。

## ポート番号
ポート番号は110, 143, 993, 995を使用するためポートフォワーディングの設定が必要。

## dovecotの起動と停止
起動にはsystemdを使用しており以下のようにする。
```shell
systemctl start dovecot     # 起動
systemctl stop  dovecot     # 停止
```

## エントリポイント
エントリポイントは/usr/local/sh/system/imap-system.shである。
/usr/local/etc/users.txtを起動前に用意するとメールユーザーが自動で作成される。
しかし最初のコンテナ起動ではsystemdでdovecotサービスは起動できないので以下のように実行しなければならない。
```shell
docker exec -i kacpp-imap "/usr/local/sh/system/imap-system-init.sh"
```
これでdovecotがサービスとして登録され次回以降は自動で起動する。

## 使い方
```shell
docker image pull kagalpandh/kacpp-imap
docker run -dit --name kacpp-smtp -p 110:110 -p 143:143 -p 993:993 -p 995:995 \
    --privileged --cap-add=SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v  /home/local_etc:/usr/local/etc -v /home:/home/mail_users kagalpandh/kacpp-imap
#各種サービス起動
docker exec -i kacpp-imap "/usr/local/sh/system/imap-system-init.sh"
```
systemdを起動するため--privileged --cap-add=SYS_ADMINのオプション指定は必要である。
systemctlがDockerfileで使用できないため各種サービスを起動する/usr/local/sh/system/imap-system-init.sh
がある。もしも必要なサービスのみ起動したいなら手動で設定する。

##ベースイメージ
kagalpandh/kacpp-pydev

# その他
DockerHub: [kagalpandh/kacpp-postgres](https://hub.docker.com/repository/docker/kagalpandh/kacpp-imap)<br />
GitHub: [karakawa88/kacpp-postgres](https://github.com/karakawa88/kacpp-imap)

