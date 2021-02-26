export CHOOSENIM_CHOOSE_VERSION=1.2.10
apt install -y zlib1g-dev wget build-essential
wget -qO - https://nim-lang.org/choosenim/init.sh | sh
nimble refresh
nimble build -y  --verbose
bash test/mini.sh
