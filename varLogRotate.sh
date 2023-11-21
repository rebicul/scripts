/var/log/httpd/*.log {
    daily
    rotate 7
    compress
    copytruncate
    missingok
    notifempty
    dateext
    endscript
}