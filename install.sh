#!/bin/bash

get_free_port() {
    for port in $(seq 49152 65535); do
        (echo >/dev/tcp/localhost/$port) >/dev/null 2>&1
        result=$?
        if [[ $result -ne 0 ]]; then
            echo "$port"
            return
        fi
    done
    echo "Не удалось найти свободный порт"
    exit 1
}

# Инициализация файла конфигурации
if [ ! -f config.ini ]; then
    echo "Файл конфигурации не найден"
    exit 1
fi

APP_NAME=$(grep APP_NAME config.ini | cut -d '=' -f 2)
RESTART_POLICY=$(grep RESTART_POLICY config.ini | cut -d '=' -f 2)
LOCAL_HOST="127.0.0.1"
LOCAL_PORT=$(get_free_port)
PUBLIC_HOST=$(grep PUBLIC_HOST config.ini | cut -d '=' -f 2)
PUBLIC_PORT=$(grep PUBLIC_PORT config.ini | cut -d '=' -f 2)

# Docker
echo "Установка Docker..."
if  ! command -v docker &> /dev/null; then
    if command -v apt &> /dev/null; then
        apt install docker.io -y &
    elif command -v yum &> /dev/null; then
        yum install docker -y &
    elif command -v dnf &> /dev/null; then
        dnf install docker -y &
    elif command -v zypper &> /dev/null; then
        zypper install docker -y &
    else
        echo "Не удалось автоматически установить Docker. Неизвестный дистрибутив Linux."
        echo "Попробуйте установить Docker вручную и повторить установку приложения."
        exit 1
    fi
    pid=$!
    wait $pid
else
    echo "Docker уже установлен"
fi

# Nginx
echo "Установка nginx..."
if [ ! -f /etc/nginx/nginx.conf ]; then
    if command -v apt &> /dev/null; then
        apt install nginx -y &
    elif command -v yum &> /dev/null; then
        yum install nginx -y &
    elif command -v dnf &> /dev/null; then
        dnf install nginx -y &
    elif command -v zypper &> /dev/null; then
        zypper install nginx -y &
    else
        echo "Не удалось автоматически установить Nginx. Неизвестный дистрибутив Linux."
        echo "Попробуйте установить Nginx вручную и повторить установку приложения."
        exit 1
    fi
    pid=$!
    wait $pid
else
    echo "Nginx уже установлен"
fi

cp ./nginx/app.conf /etc/nginx/sites-available/$APP_NAME.conf
ln -s /etc/nginx/sites-available/$APP_NAME.conf /etc/nginx/sites-enabled/$APP_NAME.conf

chmod o+xrw /etc/nginx/sites-available/$APP_NAME.conf
chmod o+xrw /etc/nginx/sites-enabled/$APP_NAME.conf

sed -i "s|LOCAL_HOST|$LOCAL_HOST|g" /etc/nginx/sites-available/$APP_NAME.conf
sed -i "s|LOCAL_PORT|$LOCAL_PORT|g" /etc/nginx/sites-available/$APP_NAME.conf
sed -i "s|PUBLIC_HOST|$PUBLIC_HOST|g" /etc/nginx/sites-available/$APP_NAME.conf
sed -i "s|PUBLIC_PORT|$PUBLIC_PORT|g" /etc/nginx/sites-available/$APP_NAME.conf

nginx -t &
pid=$!
wait $pid

nginx -s reload &
pid=$!
wait $pid

# Application
echo "Инициализация приложения..."
docker build --no-cache -t $APP_NAME:latest ./app &
pid=$!
wait $pid

docker run -d --restart=$RESTART_POLICY -p $LOCAL_HOST:$LOCAL_PORT:80 -i $APP_NAME:latest &
pid=$!
wait $pid

echo "Установка завершена успешно"
echo "Приложение доступно по >" $PUBLIC_HOST:$PUBLIC_PORT
