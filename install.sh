#!/bin/bash

success() {
    GREEN='\033[0;32m'
    NC='\033[0m' # No Color
    DATE=$(date +"[%Y-%m-%d %H:%M:%S]")

    echo -e "${GREEN}${DATE} $1${NC}"
}

error() {
    RED='\033[0;31m'
    NC='\033[0m' # No Color
    DATE=$(date +"[%Y-%m-%d %H:%M:%S]")

    echo -e "${RED}${DATE} ОШИБКА: $1${NC}"
}


get_free_port() {
    local HOST=$1

    for port in $(seq 49152 65535); do
        (echo >/dev/tcp/"$HOST"/"$port") >/dev/null 2>&1
        result=$?
        if [[ $result -ne 0 ]]; then
            echo "$port"
            return
        fi
    done
    error "Не удалось найти свободный порт"
    exit 1
}

# Инициализация файла конфигурации
if [ ! -f config.ini ]; then
    error "Файл конфигурации не найден"
    exit 1
fi

APP_NAME=$(grep APP_NAME config.ini | cut -d '=' -f 2)
RESTART_POLICY=$(grep RESTART_POLICY config.ini | cut -d '=' -f 2)
LOCAL_HOST="127.0.0.1"
LOCAL_PORT=$(get_free_port $LOCAL_HOST)
PUBLIC_HOST=$(grep PUBLIC_HOST config.ini | cut -d '=' -f 2)
PUBLIC_PORT=$(grep PUBLIC_PORT config.ini | cut -d '=' -f 2)

# Docker
success "Установка Docker..."
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
        error "Не удалось автоматически установить Docker. Неизвестный дистрибутив Linux.
        Попробуйте установить Docker вручную и повторить установку приложения."
        exit 1
    fi
    pid=$!
    wait $pid
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        success "Docker успешно установлен"
    else
        error "Установка Docker завершилась с ошибкой (exit code: $exit_code)"
        exit 1
    fi
else
    success "Docker уже установлен"
fi

# Nginx
success "Установка nginx..."
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
        error "Не удалось автоматически установить Nginx. Неизвестный дистрибутив Linux.
        Попробуйте установить Nginx вручную и повторить установку приложения."
        exit 1
    fi
    pid=$!
    wait $pid
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        success "Nginx успешно установлен"
    else
        error "Установка Nginx завершилась с ошибкой (exit code: $exit_code)"
        exit 1
    fi
else
    success "Nginx уже установлен"
fi

cp ./nginx/app.conf /etc/nginx/sites-available/"$APP_NAME".conf
cp_status=$?
ln -s /etc/nginx/sites-available/"$APP_NAME".conf /etc/nginx/sites-enabled/"$APP_NAME".conf
ln_status=$?

if [ $cp_status -eq 0 ]; then
    success "Копирование конфигурации nginx успешно завершено"
else
    error "Копирование конфигурации nginx завершилась с ошибкой (exit code: $exit_code)"
    exit 1
fi

if [ $ln_status -eq 0 ]; then
    success "Установка конфигурации nginx успешно завершено"
else
    error "Установка конфигурации nginx завершилась с ошибкой (exit code: $exit_code)"
    exit 1
fi



chmod o+xrw /etc/nginx/sites-available/"$APP_NAME".conf
chmod o+xrw /etc/nginx/sites-enabled/"$APP_NAME".conf

sed -i "s|LOCAL_HOST|$LOCAL_HOST|g" /etc/nginx/sites-available/"$APP_NAME".conf
sed -i "s|LOCAL_PORT|$LOCAL_PORT|g" /etc/nginx/sites-available/"$APP_NAME".conf
sed -i "s|PUBLIC_HOST|$PUBLIC_HOST|g" /etc/nginx/sites-available/"$APP_NAME".conf
sed -i "s|PUBLIC_PORT|$PUBLIC_PORT|g" /etc/nginx/sites-available/"$APP_NAME".conf

nginx -t &
pid=$!
wait $pid
status=$?

if [ $status -eq 0 ]; then
    success "Проверка конфигурации nginx успешно завершена"
else
    error "Проверка конфигурации nginx завершилась с ошибкой (exit code: $exit_code)"
    exit 1
fi

nginx -s reload &
pid=$!
wait $pid
status=$?

if [ $status -eq 0 ]; then
    success "Перезагрузка nginx успешно завершена"
else
    error "Перезагрузка nginx завершилась с ошибкой (exit code: $exit_code)"
    exit 1
fi

# Application
success "Инициализация приложения..."
docker build --no-cache -t "$APP_NAME":latest ./app &
pid=$!
wait $pid
exit_code=$?

if [ $exit_code -eq 0 ]; then
    success "Сборка приложения успешно завершена"
else
    error "Сборка приложения завершилась с ошибкой (exit code: $exit_code)"
    exit 1
fi

docker run -d --restart="$RESTART_POLICY" -p $LOCAL_HOST:"$LOCAL_PORT":80 --name "$APP_NAME" -i "$APP_NAME":latest &
pid=$!
wait $pid
exit_code=$?

if [ $exit_code -eq 0 ]; then
    success "Запуск приложения успешно завершен"
else
    error "Запуск приложения завершился с ошибкой (exit code: $exit_code)"
    exit 1
fi

success "Установка завершена успешно!
Приложение доступно по >  $PUBLIC_HOST:$PUBLIC_PORT"
exit 0
