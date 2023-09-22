#!/bin/bash

defaultURL="https://ntfy.sh"
port="8092"
username="admin"
password="password"
runOnSudo="1"

is_valid_url() {
  local url="$1"
  local url_pattern="https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)"
  if [[ ! "$url" =~ $url_pattern ]]; then
    echo "Invalid URL: $url"
    exit 1
  fi
}

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  -i, --url   URL      Specify the URL where the ntfy server run (default: $defaultURL)"
  echo "  -h, --help           Display this help message"
  exit 1
}


argument_check() {
  local error_messagge=$1
  local numbers_of_arguments=$2

  if [ ! $numbers_of_arguments -ge 2 ]; then
    echo $error_message
    exit 1
  fi
}

run_sudo_command_or_not() {
  local command=$1
  if [ $runOnSudo = "0" ]; then
    eval "sudo $command"
  else
    eval $command
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url)
      argument_check "Error: The -u|--url option requires an argument." $#
      is_valid_url $2
      defaultURL=$2      
      shift 2
      ;;
    -U|--username)
      argument_check "Error: The -U|--username options requires an argument." $#
      username=$2
      shift 2
      ;;
    -P|--password)
      argument_check "Error: The -P|--password options requires an argument." $#
      password=$2
      shift 2
      ;;
    -s|--sudo)
      runOnSudo="0"
      shift
      ;;
    -p|--port)
      argument_check "Error: The -p|--port option requires an argument."
      port=$2
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Invalid option: $1"
      usage
      ;;
  esac
done

sed -i "s#base-url: \"\"#base-url: \"${defaultURL}\"#" server.yml
sed -i "s#- 8092:80#- ${port}:80#" docker-compose.yml

sudo mkdir /var/cache/ntfy && touch /var/cache/ntfy/cache.db
sudo mkdir /var/lib/ntfy && touch /var/lib/ntfy/user.db
sudo mkdir /etc/ntfy && sudo cp server.yml /etc/ntfy/server.yml

run_sudo_command_or_not "docker compose up -d"

container_id=$(run_sudo_command_or_not "docker ps -f name=ntfy" | grep -w ntfy | awk '{ print $1 }')

run_sudo_command_or_not "docker exec $container_id ntfy user add --role=admin $username"

uri="${defaultURL:8}"

nginx_config_block="server {

  server_name $uri;

  location / {
    proxy_pass         http://127.0.0.1:$port;

    proxy_http_version 1.1;

    proxy_buffering off;
    proxy_request_buffering off;
    proxy_redirect off;

    proxy_set_header Host \$http_host;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \"upgrade\";
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

    proxy_connect_timeout 3m;
    proxy_send_timeout 3m;
    proxy_read_timeout 3m;

    client_max_body_size 0; # Stream request body to backend

  }
}"

echo "$nginx_config_block" > /etc/nginx/site-enabed/ntfy.conf
sudo certbot --nginx -d $uri

echo "Finish !"
echo "Don't forget to add the subdomain in your reverse DNS list."
echo "Here is your access token :"
echo "$(run_sudo_command_or_not "docker exec $container_idntfy ntfy token list $username"
