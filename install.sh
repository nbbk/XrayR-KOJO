#!/usr/bin/env bash
set -Eeuo pipefail

REPO="nbbk/XrayR-KOJO"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main"
API_BASE="https://api.github.com/repos/${REPO}"
INSTALL_DIR="/usr/local/XrayR"
CONFIG_DIR="/etc/XrayR"
SERVICE_FILE="/etc/systemd/system/XrayR.service"
MANAGER_FILE="/usr/bin/XrayR"
MANAGER_LINK="/usr/bin/xrayr"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

info()  { echo -e "${BLUE}[INFO]${PLAIN} $*"; }
ok()    { echo -e "${GREEN}[OK]${PLAIN} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${PLAIN} $*"; }
fatal() { echo -e "${RED}[ERROR]${PLAIN} $*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || fatal "必须使用 root 用户运行此脚本。"
command -v systemctl >/dev/null 2>&1 || fatal "当前系统没有 systemd/systemctl，暂不支持。"

TMP_DIR="$(mktemp -d)"
BACKUP_ROOT="${TMP_DIR}/rollback"
mkdir -p "${BACKUP_ROOT}"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

install_dependencies() {
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y curl wget unzip tar ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget unzip tar ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget unzip tar ca-certificates
    else
        fatal "未识别到 apt-get/dnf/yum，请先手动安装 curl、unzip、tar。"
    fi
}

map_arch() {
    local machine
    machine="$(uname -m)"
    case "${machine}" in
        x86_64|amd64)       ASSET_ARCH="64" ;;
        i386|i486|i586|i686) ASSET_ARCH="32" ;;
        aarch64|arm64)      ASSET_ARCH="arm64-v8a" ;;
        armv7l|armv7*)      ASSET_ARCH="arm32-v7a" ;;
        armv6l|armv6*)      ASSET_ARCH="arm32-v6" ;;
        armv5l|armv5*)      ASSET_ARCH="arm32-v5" ;;
        mips)               ASSET_ARCH="mips32" ;;
        mipsel)             ASSET_ARCH="mips32le" ;;
        mips64)             ASSET_ARCH="mips64" ;;
        mips64el)           ASSET_ARCH="mips64le" ;;
        ppc64le)            ASSET_ARCH="ppc64le" ;;
        riscv64)            ASSET_ARCH="riscv64" ;;
        s390x)              ASSET_ARCH="s390x" ;;
        *) fatal "暂不支持 CPU 架构：${machine}" ;;
    esac
    info "检测到 CPU：${machine} -> XrayR-linux-${ASSET_ARCH}.zip"
}

normalize_version() {
    local requested="${1:-}"
    if [[ -n "${requested}" ]]; then
        [[ "${requested}" == v* ]] && VERSION="${requested}" || VERSION="v${requested}"
        return
    fi

    VERSION="$(curl -fsSL -H 'Accept: application/vnd.github+json' "${API_BASE}/releases/latest" \
        | grep -m1 '"tag_name"' \
        | cut -d '"' -f4 || true)"

    [[ -n "${VERSION}" ]] || fatal "未找到 ${REPO} 的最新 Release。请先在 GitHub Releases 创建版本并上传 XrayR-linux-*.zip。"
}

backup_current() {
    HAD_BINARY=0
    WAS_ACTIVE=0

    if systemctl is-active --quiet XrayR 2>/dev/null; then
        WAS_ACTIVE=1
    fi

    if [[ -x "${INSTALL_DIR}/XrayR" ]]; then
        HAD_BINARY=1
        cp -a "${INSTALL_DIR}" "${BACKUP_ROOT}/program"
        info "已备份当前 XrayR 程序，用于更新失败时回滚。"
    fi

    if [[ -d "${CONFIG_DIR}" ]]; then
        cp -a "${CONFIG_DIR}" "${BACKUP_ROOT}/config"
        info "已备份当前配置。"
    fi
}

rollback() {
    warn "新版本启动失败，正在自动回滚……"
    systemctl stop XrayR >/dev/null 2>&1 || true

    if [[ -d "${BACKUP_ROOT}/program" ]]; then
        rm -rf "${INSTALL_DIR}"
        cp -a "${BACKUP_ROOT}/program" "${INSTALL_DIR}"
    fi

    if [[ -d "${BACKUP_ROOT}/config" ]]; then
        rm -rf "${CONFIG_DIR}"
        cp -a "${BACKUP_ROOT}/config" "${CONFIG_DIR}"
    fi

    systemctl daemon-reload
    if [[ ${WAS_ACTIVE} -eq 1 ]]; then
        systemctl start XrayR || true
    fi

    if systemctl is-active --quiet XrayR 2>/dev/null; then
        ok "已回滚到旧版本，服务恢复运行。"
    else
        warn "已恢复旧文件，但服务仍未运行。请执行：xrayr log"
    fi
}

download_release() {
    ASSET_NAME="XrayR-linux-${ASSET_ARCH}.zip"
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET_NAME}"
    ZIP_FILE="${TMP_DIR}/${ASSET_NAME}"
    EXTRACT_DIR="${TMP_DIR}/extract"
    mkdir -p "${EXTRACT_DIR}"

    info "准备安装 ${VERSION}"
    info "下载 ${DOWNLOAD_URL}"
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 "${DOWNLOAD_URL}" -o "${ZIP_FILE}" \
        || fatal "下载失败。请确认 Release ${VERSION} 中存在 ${ASSET_NAME}。"

    unzip -q "${ZIP_FILE}" -d "${EXTRACT_DIR}"
    [[ -f "${EXTRACT_DIR}/XrayR" ]] || fatal "Release 压缩包格式异常：根目录未找到 XrayR。"
    chmod +x "${EXTRACT_DIR}/XrayR"
}

install_program() {
    if [[ ${WAS_ACTIVE} -eq 1 ]]; then
        systemctl stop XrayR || true
    fi

    rm -rf "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}" "${CONFIG_DIR}"
    cp -a "${EXTRACT_DIR}/." "${INSTALL_DIR}/"
    chmod +x "${INSTALL_DIR}/XrayR"
    printf '%s\n' "${VERSION}" > "${INSTALL_DIR}/.kojo-version"

    # 配置文件只在不存在时初始化，更新绝不覆盖用户 config.yml。
    if [[ ! -f "${CONFIG_DIR}/config.yml" ]]; then
        if [[ -f "${INSTALL_DIR}/config.yml" ]]; then
            cp "${INSTALL_DIR}/config.yml" "${CONFIG_DIR}/config.yml"
        else
            curl -fsSL "${RAW_BASE}/config/config.yml.example" -o "${CONFIG_DIR}/config.yml" \
                || fatal "无法获取默认 config.yml。"
        fi
        warn "这是首次安装，请编辑 ${CONFIG_DIR}/config.yml 后确认面板参数。"
    fi

    for f in dns.json route.json custom_inbound.json custom_outbound.json rulelist; do
        if [[ ! -f "${CONFIG_DIR}/${f}" && -f "${INSTALL_DIR}/${f}" ]]; then
            cp "${INSTALL_DIR}/${f}" "${CONFIG_DIR}/${f}"
        fi
    done

    # Geo 数据随 Release 更新；回滚时会一起恢复配置目录。
    for f in geoip.dat geosite.dat; do
        if [[ -f "${INSTALL_DIR}/${f}" ]]; then
            cp "${INSTALL_DIR}/${f}" "${CONFIG_DIR}/${f}"
        fi
    done
}

install_service_and_manager() {
    curl -fsSL "${RAW_BASE}/systemd/XrayR.service" -o "${SERVICE_FILE}" \
        || fatal "下载 XrayR.service 失败。"

    curl -fsSL "${RAW_BASE}/scripts/xrayr" -o "${MANAGER_FILE}" \
        || fatal "下载管理脚本失败。"

    chmod 755 "${MANAGER_FILE}"
    rm -f "${MANAGER_LINK}"
    ln -s "${MANAGER_FILE}" "${MANAGER_LINK}"

    systemctl daemon-reload
    systemctl enable XrayR >/dev/null
}

start_and_verify() {
    systemctl restart XrayR || true
    sleep 3

    if systemctl is-active --quiet XrayR; then
        ok "XrayR ${VERSION} 已安装并运行。"
        return 0
    fi

    if [[ ${HAD_BINARY} -eq 1 ]]; then
        rollback
        fatal "更新失败，已执行自动回滚。"
    fi

    warn "XrayR 已安装，但当前没有成功启动。首次安装通常需要先配置面板参数。"
    echo -e "请执行：${GREEN}xrayr config${PLAIN}"
    echo -e "然后执行：${GREEN}xrayr restart${PLAIN}"
    echo -e "查看日志：${GREEN}xrayr log${PLAIN}"
}

main() {
    echo -e "${GREEN}========================================${PLAIN}"
    echo -e "${GREEN}       XrayR-KOJO 安装 / 更新程序${PLAIN}"
    echo -e "${GREEN}========================================${PLAIN}"

    install_dependencies
    map_arch
    normalize_version "${1:-}"
    backup_current
    download_release
    install_program
    install_service_and_manager
    start_and_verify

    echo
    echo "管理命令：xrayr"
    echo "配置文件：${CONFIG_DIR}/config.yml"
    echo "当前版本：${VERSION}"
    echo
}

main "$@"
