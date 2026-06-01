# Static file server - Ansible

Ansible-плейбук и роли для настройки сервера раздачи статики (nginx, отдаёт картинки
по пути `/images`). Тестовое окружение - Docker-контейнер на Ubuntu 24.04 с
`openssh-server`, поднимается через Docker Compose.

## Что делает

| Роль | Назначение |
|------|-----------|
| `common` | `apt update` (+опц. `upgrade`), установка утилит: htop, ncdu, git, nano (список расширяемый) |
| `users`  | создание/удаление пользователей и кастомных групп; имя, shell, состояние, пароль (хеш), ssh-ключ, группы - всё из vars |
| `zsh`    | oh-my-zsh **только** пользователям с `shell=zsh` |
| `ssh`    | хардненинг sshd: запрет root-логина, запрет пустых паролей, `LogLevel VERBOSE`, выключение X11Forwarding |
| `nginx`  | установка nginx, vhost с `/images` (autoindex + отдача файлов), gzip, логирование запросов, кэш 1 час |
| `static` | заливка картинок из `files/images/` в `/var/www/images` |

Все роли **идемпотентны** - повторный прогон не вносит изменений.

## Требования (на машине, откуда запускается Ansible)

- Docker + Docker Compose
- Ansible (`ansible-playbook`)
- Коллекции Ansible: `ansible-galaxy collection install -r requirements.yml`

## Запуск

```bash
# 1. Сгенерить одноразовый ssh-ключ и поднять окружение одной командой
#    (ssh-keygen если ключа нет + docker compose up). Ключ в git НЕ коммитится.
./scripts/setup.sh

# 2. Поставить зависимости Ansible
ansible-galaxy collection install -r requirements.yml

# 3. Прогнать плейбук (vars в group_vars/all.yml, inventory в inventory/hosts.ini)
ansible-playbook playbook.yml
```

> **Запуск из WSL (папка на диске Windows, `/mnt/c/...`)**
> Такая папка world-writable, и Ansible из соображений безопасности целиком
> игнорирует лежащий в ней `ansible.cfg` (теряются inventory, host_key_checking,
> ssh_args, формат вывода). Плюс ssh отвергает приватный ключ на `/mnt/c` - у файла
> там всегда права 0777. Симптомы по очереди: `no hosts matched`, затем
> `Host key verification failed`, затем `UNPROTECTED PRIVATE KEY FILE`.
>
> Используй обёртку - она восстанавливает все настройки через env и кладёт копию
> ключа с правами 0600 в `~/.ssh`:
>
> ```bash
> ./scripts/run.sh                 # обычный прогон
> ./scripts/run.sh --tags static   # пробросить аргументы в ansible-playbook
> ```

Без скрипта то же самое вручную:

```bash
ssh-keygen -t ed25519 -N "" -f docker/keys/id_ed25519
docker compose up -d --build
```

Проброшенные порты: `2222 -> 22` (ssh), `80 -> 80` (nginx).
Если порт 80 на хосте занят: `HTTP_PORT=8080 docker compose up -d --build`.

## Проверка результата

```bash
# Структура файлов (autoindex)
curl http://localhost/images/

# Конкретное изображение
curl http://localhost/images/sample-red.svg

# Заголовки кэширования (Expires / Cache-Control max-age=3600) и gzip
curl -I http://localhost/images/sample-red.svg

# SSH открыт; root-логин запрещён, вход по ключу под пользователем
ssh -i docker/keys/id_ed25519 -p 2222 deploy@localhost
ssh -i docker/keys/id_ed25519 -p 2222 alice@localhost   # alice -> zsh + oh-my-zsh
```

> На WSL ключ из `docker/keys/` лежит на `/mnt/c` с правами 0777 - ssh его отвергнет
> ("UNPROTECTED PRIVATE KEY FILE"). Используй копию с правами 0600, которую кладёт
> `scripts/run.sh`:
>
> ```bash
> ssh -i ~/.ssh/static-server-test-key -p 2222 deploy@localhost
> ssh -i ~/.ssh/static-server-test-key -p 2222 alice@localhost
> ```

В браузере: `http://localhost/images/` - листинг, клик по файлу - изображение.

## Картинки из задания

В репо лежат 3 SVG-сэмпла. Реальную подборку с Google Drive:

```bash
pip install gdown
./scripts/download_images.sh   # скачает в files/images/
ansible-playbook playbook.yml --tags static
```

## Структура

```
.
├── ansible.cfg
├── docker-compose.yml
├── docker/
│   ├── Dockerfile           # Ubuntu 24.04 + systemd + openssh-server + deploy user
│   └── keys/                # тестовый ssh-ключ (см. ниже)
├── inventory/hosts.ini
├── group_vars/all.yml       # ВСЯ конфигурация: users, groups, packages, ssh, nginx
├── playbook.yml
├── requirements.yml
├── files/images/            # картинки для раздачи
├── scripts/download_images.sh
└── roles/{common,users,zsh,ssh,nginx,static}/
```

## Про ssh-ключ

Приватный ключ в git **не коммитится** (см. `.gitignore`). `scripts/setup.sh`
генерит одноразовую пару `docker/keys/id_ed25519` локально перед запуском - она
подходит только к тест-контейнеру и нигде больше не используется. На свежем клоне
просто запусти `./scripts/setup.sh`.

## Подключение под root запрещено - как тогда Ansible работает?

Контейнер создаёт пользователя `deploy` (sudo NOPASSWD, вход по тестовому ключу).
Ansible подключается под ним; роль `ssh` затем выключает root-логин. Доступ не теряется.
