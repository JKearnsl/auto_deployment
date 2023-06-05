#!/bin/bash

success() {
    GREEN='\033[0;32m'
    NC='\033[0m' # No Color
    DATE=$(date +"[%Y-%m-%d %H:%M:%S]")

    echo -e "${GREEN}${DATE} $1${NC}"
}

warning() {
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
    DATE=$(date +"[%Y-%m-%d %H:%M:%S]")

    echo -e "${YELLOW}${DATE} ПРЕДУПРЕЖДЕНИЕ: $1${NC}"
}

APP_NAME=$(grep APP_NAME config.ini | cut -d '=' -f 2)

# Docker
success "Остановка и удаление приложения $APP_NAME..."
docker stop "$APP_NAME" &
pid=$!
wait $pid
status=$?
if [ $status -ne 0 ]; then
    warning "Не удалось остановить контейнер"
fi

docker rm "$APP_NAME" &
pid=$!
wait $pid
status=$?
if [ $status -ne 0 ]; then
    warning "Не удалось удалить контейнер"
fi

docker rmi "$APP_NAME" &
pid=$!
wait $pid
status=$?
if [ $status -ne 0 ]; then
    warning "Не удалось удалить образ"
fi


# Nginx
success "Удаление конфигурации Nginx..."
rm /etc/nginx/sites-available/"$APP_NAME".conf &
pid=$!
wait $pid
status=$?
if [ $status -ne 0 ]; then
    warning "Не удалось удалить конфигурацию Nginx"
fi

rm /etc/nginx/sites-enabled/"$APP_NAME".conf &
pid=$!
wait $pid
status=$?
if [ $status -ne 0 ]; then
    warning "Не удалось удалить конфигурацию Nginx"
fi

nginx -s reload &
pid=$!
wait $pid
status=$?
if [ $status -ne 0 ]; then
    warning "Не удалось перезапустить Nginx"
fi

success "Удаление успешно завершено!"
exit 0
