#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Labnana Image Generation Script
# API: https://docs.marswave.ai/openapi-labnana.html
# Platform: macOS, Linux, Windows (Git Bash/WSL)
# ============================================

PROMPT="${1:-}"
SIZE="${2:-2K}"
RATIO="${3:-16:9}"

# 配置
API_ENDPOINT="https://api.labnana.com/openapi/v1/images/generation"
MAX_RETRIES=3
INITIAL_TIMEOUT=600
RETRY_DELAY=5

# 临时文件追踪（用于中断清理）
TEMP_OUTPUT_FILE=""

# ============================================
# 平台检测
# ============================================

detect_platform() {
  case "$(uname -s)" in
    Darwin*)  echo "macos" ;;
    Linux*)   echo "linux" ;;
    CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
    *)        echo "unknown" ;;
  esac
}

PLATFORM=$(detect_platform)

# ============================================
# 中断清理
# ============================================

cleanup() {
  if [ -n "$TEMP_OUTPUT_FILE" ] && [ -f "$TEMP_OUTPUT_FILE" ]; then
    rm -f "$TEMP_OUTPUT_FILE"
  fi
}

trap cleanup EXIT INT TERM

# ============================================
# 跨平台工具函数
# ============================================

# 跨平台 sed -i（macOS 和 Linux 语法不同）
sed_inplace() {
  local file="$1"
  local pattern="$2"

  if [ "$PLATFORM" = "macos" ]; then
    sed -i '' "$pattern" "$file"
  else
    sed -i "$pattern" "$file"
  fi
}

# 跨平台 base64 解码
base64_decode() {
  local input="$1"
  local output="$2"

  # 尝试不同的 base64 解码方式
  if echo "$input" | base64 -d > "$output" 2>/dev/null; then
    return 0
  elif echo "$input" | base64 -D > "$output" 2>/dev/null; then
    # macOS 旧版本使用 -D
    return 0
  elif echo "$input" | base64 --decode > "$output" 2>/dev/null; then
    # 某些系统使用 --decode
    return 0
  elif command -v openssl &>/dev/null; then
    # 兜底：使用 openssl
    echo "$input" | openssl base64 -d > "$output" 2>/dev/null
    return $?
  else
    return 1
  fi
}

# 跨平台查找 curl
find_curl() {
  # 按优先级尝试不同路径
  local curl_paths=(
    "/usr/bin/curl"           # macOS, Linux 标准路径
    "/bin/curl"               # 某些 Linux 发行版
    "/usr/local/bin/curl"     # Homebrew (macOS)
    "/mingw64/bin/curl"       # Git Bash (Windows)
    "/c/Windows/System32/curl.exe"  # Windows 内置 curl
  )

  for path in "${curl_paths[@]}"; do
    if [ -x "$path" ]; then
      echo "$path"
      return 0
    fi
  done

  # 最后尝试 PATH 中的 curl
  if command -v curl &>/dev/null; then
    command -v curl
    return 0
  fi

  return 1
}

# 跨平台获取 shell 配置文件
get_shell_rc() {
  local rc_files=()

  case "$PLATFORM" in
    macos)
      # macOS 默认 zsh，但也可能用 bash
      rc_files=(~/.zshrc ~/.bash_profile ~/.bashrc ~/.profile)
      ;;
    linux)
      # Linux 通常用 bashrc
      rc_files=(~/.bashrc ~/.zshrc ~/.profile)
      ;;
    windows)
      # Git Bash 使用 bashrc
      rc_files=(~/.bashrc ~/.bash_profile ~/.profile)
      ;;
    *)
      rc_files=(~/.bashrc ~/.zshrc ~/.profile)
      ;;
  esac

  # 返回第一个存在的文件，或第一个作为默认
  for rc in "${rc_files[@]}"; do
    if [ -f "$rc" ]; then
      echo "$rc"
      return 0
    fi
  done

  # 如果都不存在，返回平台默认
  case "$PLATFORM" in
    macos)  echo ~/.zshrc ;;
    *)      echo ~/.bashrc ;;
  esac
}

# 生成随机数（兼容无 $RANDOM 的环境）
get_random() {
  if [ -n "${RANDOM:-}" ]; then
    echo $((RANDOM % 10000))
  elif [ -f /dev/urandom ]; then
    od -An -tu2 -N2 /dev/urandom | tr -d ' '
  else
    # 最后兜底：用时间戳的一部分
    date +%N 2>/dev/null | cut -c1-4 || echo "0000"
  fi
}

# ============================================
# 环境变量加载（支持多种格式）
# ============================================

load_env_var() {
  local var_name="$1"
  local rc_file
  local line
  local value=""

  for rc_file in ~/.zshrc ~/.bashrc ~/.bash_profile ~/.profile; do
    if [ -f "$rc_file" ]; then
      # 查找 export VAR=... 行（支持 =、=" 、=' 格式）
      line=$(grep -E "^export ${var_name}=" "$rc_file" 2>/dev/null | tail -1) || true
      if [ -n "$line" ]; then
        # 提取等号后的部分
        value="${line#*=}"
        # 去除首尾引号（双引号或单引号）
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        # 展开 $HOME 和 ~
        value="${value/\$HOME/$HOME}"
        value="${value/#\~/$HOME}"
        if [ -n "$value" ]; then
          export "$var_name"="$value"
          return 0
        fi
      fi
    fi
  done
  return 1
}

[ -z "${LABNANA_API_KEY:-}" ] && load_env_var "LABNANA_API_KEY" || true
[ -z "${LABNANA_OUTPUT_DIR:-}" ] && load_env_var "LABNANA_OUTPUT_DIR" || true

# ============================================
# 依赖检查与安装引导
# ============================================

check_dependencies() {
  local missing_deps=()
  local install_cmd=""

  # 检查 jq
  if ! command -v jq &>/dev/null; then
    missing_deps+=("jq")
  fi

  # 检查 curl
  if ! find_curl &>/dev/null; then
    missing_deps+=("curl")
  fi

  # 如果有缺失依赖，自动安装
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "→ 检测到缺失的必备工具: ${missing_deps[*]}" >&2
    echo "  正在自动安装..." >&2
    echo "" >&2

    case "$PLATFORM" in
      macos)
        install_cmd="brew install ${missing_deps[*]}"
        if ! command -v brew &>/dev/null; then
          echo "Error: 未检测到 Homebrew" >&2
          echo "  请先安装 Homebrew: https://brew.sh" >&2
          echo "  或手动安装: ${missing_deps[*]}" >&2
          exit 1
        fi
        ;;
      linux)
        # 检测 Linux 发行版
        if command -v apt-get &>/dev/null; then
          install_cmd="sudo apt-get update && sudo apt-get install -y ${missing_deps[*]}"
        elif command -v yum &>/dev/null; then
          install_cmd="sudo yum install -y ${missing_deps[*]}"
        elif command -v dnf &>/dev/null; then
          install_cmd="sudo dnf install -y ${missing_deps[*]}"
        elif command -v pacman &>/dev/null; then
          install_cmd="sudo pacman -S --noconfirm ${missing_deps[*]}"
        else
          echo "Error: 未检测到支持的包管理器" >&2
          echo "  请手动安装: ${missing_deps[*]}" >&2
          exit 1
        fi
        ;;
      windows)
        if command -v choco &>/dev/null; then
          install_cmd="choco install -y ${missing_deps[*]}"
        elif command -v scoop &>/dev/null; then
          install_cmd="scoop install ${missing_deps[*]}"
        else
          echo "Error: 未检测到 Chocolatey 或 Scoop" >&2
          echo "  请先安装包管理器:" >&2
          echo "  - Chocolatey: https://chocolatey.org/install" >&2
          echo "  - Scoop: https://scoop.sh" >&2
          echo "  或手动下载: https://stedolan.github.io/jq/download/" >&2
          exit 1
        fi
        ;;
      *)
        echo "Error: 不支持的平台" >&2
        echo "  请手动安装: ${missing_deps[*]}" >&2
        exit 1
        ;;
    esac

    # 执行安装
    if eval "$install_cmd"; then
      echo "" >&2
      echo "✓ 依赖安装成功" >&2
      echo "" >&2
    else
      echo "" >&2
      echo "Error: 自动安装失败" >&2
      echo "  请手动执行: $install_cmd" >&2
      exit 1
    fi
  fi
}

# ============================================
# 首次配置检查
# ============================================

setup_config() {
  local shell_rc
  shell_rc=$(get_shell_rc)

  echo "→ 欢迎使用 Labnana 图片生成！需要先配置一下。" >&2
  echo "  检测到平台: $PLATFORM" >&2
  echo "" >&2

  # 先检查依赖
  check_dependencies

  # 配置 API Key
  if [ -z "${LABNANA_API_KEY:-}" ]; then
    echo "1. API Key" >&2
    echo "   访问 https://labnana.com/api-keys" >&2
    echo "   (需要「帝王蕉」订阅)" >&2
    echo "" >&2
    echo -n "   请粘贴你的 API key: " >&2
    read -r api_key

    if [ -z "$api_key" ]; then
      echo "Error: API key 不能为空" >&2
      exit 1
    fi

    # 检查是否已存在配置（避免重复追加）
    if ! grep -q "^export LABNANA_API_KEY=" "$shell_rc" 2>/dev/null; then
      echo "export LABNANA_API_KEY=\"$api_key\"" >> "$shell_rc"
    else
      # 已存在则替换
      sed_inplace "$shell_rc" "s|^export LABNANA_API_KEY=.*|export LABNANA_API_KEY=\"$api_key\"|"
    fi
    export LABNANA_API_KEY="$api_key"
    echo "" >&2
  fi

  # 配置输出路径
  if [ -z "${LABNANA_OUTPUT_DIR:-}" ]; then
    echo "2. 输出路径" >&2
    echo -n "   图片保存位置 (默认: ~/Downloads): " >&2
    read -r output_dir

    # 默认使用 ~/Downloads
    if [ -z "$output_dir" ]; then
      output_dir="$HOME/Downloads"
    fi

    # 展开 ~ 符号
    output_dir="${output_dir/#\~/$HOME}"

    # 创建目录（如果不存在）
    mkdir -p "$output_dir"

    # 检查是否已存在配置（避免重复追加）
    if ! grep -q "^export LABNANA_OUTPUT_DIR=" "$shell_rc" 2>/dev/null; then
      echo "export LABNANA_OUTPUT_DIR=\"$output_dir\"" >> "$shell_rc"
    else
      sed_inplace "$shell_rc" "s|^export LABNANA_OUTPUT_DIR=.*|export LABNANA_OUTPUT_DIR=\"$output_dir\"|"
    fi
    export LABNANA_OUTPUT_DIR="$output_dir"
    echo "" >&2
  fi

  echo "✓ 配置已保存到 $shell_rc" >&2
  echo "" >&2
}

# 检查并执行首次配置
if [ -z "${LABNANA_API_KEY:-}" ] || [ -z "${LABNANA_OUTPUT_DIR:-}" ]; then
  setup_config
fi

# ============================================
# 参数验证
# ============================================

if [ -z "$PROMPT" ]; then
  echo "Usage: $0 \"<prompt>\" [size] [ratio]" >&2
  echo "  size: 1K | 2K | 4K (default: 2K)" >&2
  echo "  ratio: 16:9 | 1:1 | 9:16 | 2:3 | 3:2 | 3:4 | 4:3 | 21:9 (default: 16:9)" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 \"a cute cat\" 2K 1:1" >&2
  echo "  $0 \"cyberpunk city at night\" 4K 16:9" >&2
  exit 1
fi

# 验证 size 参数
case "$SIZE" in
  1K|2K|4K) ;;
  *) echo "Error: size 必须是 1K, 2K 或 4K" >&2; exit 1 ;;
esac

# 验证 ratio 参数
case "$RATIO" in
  16:9|1:1|9:16|2:3|3:2|3:4|4:3|21:9) ;;
  *) echo "Error: ratio 不支持 $RATIO" >&2; exit 1 ;;
esac

# ============================================
# JSON 构建（兼容无 jq 环境）
# ============================================

build_json_payload() {
  local prompt="$1"
  local size="$2"
  local ratio="$3"

  if command -v jq &> /dev/null; then
    # jq 可用时，直接构建完整 JSON 对象（自动处理所有转义）
    jq -n \
      --arg prompt "$prompt" \
      --arg size "$size" \
      --arg ratio "$ratio" \
      '{provider: "google", prompt: $prompt, imageConfig: {imageSize: $size, aspectRatio: $ratio}}'
  else
    # 无 jq 时手动转义 JSON 特殊字符
    local escaped_prompt="$prompt"
    # 按顺序转义：反斜杠必须最先
    escaped_prompt="${escaped_prompt//\\/\\\\}"     # \ -> \\
    escaped_prompt="${escaped_prompt//\"/\\\"}"     # " -> \"
    escaped_prompt="${escaped_prompt//$'\n'/\\n}"   # 换行 -> \n
    escaped_prompt="${escaped_prompt//$'\r'/\\r}"   # 回车 -> \r
    escaped_prompt="${escaped_prompt//$'\t'/\\t}"   # Tab -> \t
    # 控制字符 (0x00-0x1F) 除了已处理的 \n\r\t，其他替换为空格
    escaped_prompt=$(printf '%s' "$escaped_prompt" | tr '\000-\010\013\014\016-\037' ' ')
    echo "{\"provider\":\"google\",\"prompt\":\"$escaped_prompt\",\"imageConfig\":{\"imageSize\":\"$size\",\"aspectRatio\":\"$ratio\"}}"
  fi
}

# ============================================
# API 调用（带重试和兜底）
# ============================================

call_api_with_retry() {
  local payload="$1"
  local attempt=1
  local timeout=$INITIAL_TIMEOUT
  local response=""
  local http_code=""
  local body=""
  local sleep_time=0

  # 查找 curl
  local curl_cmd
  curl_cmd=$(find_curl) || {
    echo "Error: 未找到 curl 命令" >&2
    echo "  请安装 curl: https://curl.se/download.html" >&2
    return 1
  }

  while [ $attempt -le $MAX_RETRIES ]; do
    echo "→ 生成中... (尝试 $attempt/$MAX_RETRIES, 超时 ${timeout}s)" >&2

    response=$("$curl_cmd" -s -w "\n%{http_code}" -X POST \
      "$API_ENDPOINT" \
      -H "Authorization: Bearer $LABNANA_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      --max-time "$timeout" 2>&1) || true

    # 分离响应体和状态码
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    # 重置等待时间
    sleep_time=$RETRY_DELAY

    # 处理各种情况
    case "$http_code" in
      200)
        echo "$body"
        return 0
        ;;
      000)
        # 连接超时或网络错误
        echo "  ⚠ 网络超时，${sleep_time}s 后重试..." >&2
        ;;
      504|502|503)
        # 服务端超时/网关错误
        echo "  ⚠ 服务繁忙 (HTTP $http_code)，${sleep_time}s 后重试..." >&2
        ;;
      429)
        # 限流 - 等待更长时间
        sleep_time=$((RETRY_DELAY * 3))
        echo "  ⚠ 请求过于频繁，${sleep_time}s 后重试..." >&2
        ;;
      401)
        echo "Error: API Key 无效或已过期" >&2
        echo "  请检查 LABNANA_API_KEY 或重新获取: https://labnana.com/api-keys" >&2
        return 1
        ;;
      402)
        echo "Error: 积分不足" >&2
        echo "  请充值: https://labnana.com/pricing" >&2
        return 1
        ;;
      400)
        local error_msg
        error_msg=$(echo "$body" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "请求参数错误")
        echo "Error: $error_msg" >&2
        return 1
        ;;
      *)
        echo "  ⚠ 未知错误 (HTTP $http_code)，${sleep_time}s 后重试..." >&2
        ;;
    esac

    # 重试前等待
    sleep $sleep_time
    attempt=$((attempt + 1))
    # 递增超时时间（兜底策略）
    timeout=$((timeout + 30))
  done

  echo "Error: 多次重试后仍然失败" >&2
  echo "  最后状态: HTTP $http_code" >&2
  echo "  建议: 稍后再试，或检查网络连接" >&2
  return 1
}

# ============================================
# 提取 base64 图片数据
# ============================================

extract_image_data() {
  local body="$1"
  local base64_data=""

  if command -v jq &> /dev/null; then
    # jq 可用时，尝试多种可能的路径
    base64_data=$(echo "$body" | jq -r '
      .candidates[0].content.parts[0].inlineData.data //
      .candidates[0].content.parts[0].inline_data.data //
      .data //
      empty
    ' 2>/dev/null) || true
  else
    # 无 jq 时用 grep 提取（base64 字符集不含引号，所以这种方式安全）
    base64_data=$(echo "$body" | grep -o '"data":"[^"]*"' | tail -1 | cut -d'"' -f4 2>/dev/null) || true
  fi

  if [ -z "$base64_data" ] || [ "$base64_data" = "null" ]; then
    return 1
  fi

  echo "$base64_data"
}

# ============================================
# 生成唯一文件名
# ============================================

generate_unique_filename() {
  local base_dir="$1"
  local prefix="$2"
  local ext="$3"
  local timestamp
  local random_suffix
  local filename

  # 时间戳精确到秒
  timestamp=$(date +%Y%m%d-%H%M%S)

  # 添加 4 位随机数避免同秒冲突
  random_suffix=$(printf '%04d' "$(get_random)")

  filename="${base_dir}/${prefix}-${timestamp}-${random_suffix}.${ext}"

  # 极端情况：如果文件仍然存在，追加更多随机
  while [ -f "$filename" ]; do
    random_suffix=$(printf '%04d' "$(get_random)")
    filename="${base_dir}/${prefix}-${timestamp}-${random_suffix}.${ext}"
  done

  echo "$filename"
}

# ============================================
# 主流程
# ============================================

# 确保输出目录存在
mkdir -p "$LABNANA_OUTPUT_DIR"

# 构建请求
PAYLOAD=$(build_json_payload "$PROMPT" "$SIZE" "$RATIO")

# 调用 API（带重试）
BODY=$(call_api_with_retry "$PAYLOAD") || exit 1

# 提取图片数据
BASE64_DATA=$(extract_image_data "$BODY")
if [ -z "$BASE64_DATA" ]; then
  echo "Error: 无法提取图片数据" >&2
  echo "  响应预览: $(echo "$BODY" | head -c 200)" >&2
  exit 1
fi

# 生成唯一文件名
OUTPUT_FILE=$(generate_unique_filename "$LABNANA_OUTPUT_DIR" "labnana" "jpg")
TEMP_OUTPUT_FILE="$OUTPUT_FILE"  # 标记为临时文件，供 trap 清理

# 解码并保存（跨平台）
if ! base64_decode "$BASE64_DATA" "$OUTPUT_FILE"; then
  echo "Error: base64 解码失败" >&2
  echo "  尝试安装 openssl 或检查 base64 命令" >&2
  exit 1
fi

# 验证文件
if [ ! -s "$OUTPUT_FILE" ]; then
  echo "Error: 生成的文件为空" >&2
  rm -f "$OUTPUT_FILE"
  exit 1
fi

# 成功，取消临时文件标记
TEMP_OUTPUT_FILE=""

# 输出结果
FILE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
echo "✓ $OUTPUT_FILE ($FILE_SIZE)" >&2
echo "$OUTPUT_FILE"
