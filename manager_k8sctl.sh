#!/bin/bash

# ==============================
# 🚀 Kubernetes 管理工具
# 集成 fzf + 命令预览/编辑 + 高危操作密码验证
# ==============================

# 配置文件
CONFIG_FILE="$HOME/.k8s-manager-config"
HISTORY_FILE="$HOME/.k8s-manager-history"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 集群配置（可后续改为 kubectl config get-contexts）
clusters=(
    "/opt/cce/cce-48c915gn.yaml"
    "/opt/cce/cce-gzk0qlzk.yaml"
    "/opt/cce/cce-xrg955qz.yaml"
    "/opt/cce/cce-k5sn275j.yaml"
    "/opt/cce/cce-2ys5dxch.yaml"
    "/opt/cce/cce-p6w3c5z8.yaml"
)

# 全局变量
cluster=""
current_ns="default"

# ==============================
# 🧰 工具函数
# ==============================

log_info()    { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error()   { echo -e "${RED}❌ $1${NC}"; }

# 保存配置
save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
LAST_CLUSTER=$cluster
LAST_NAMESPACE=$current_ns
EOF
}

# 加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE" 2>/dev/null
        if [[ -n "$LAST_CLUSTER" ]] && [[ -f "$LAST_CLUSTER" ]]; then
            cluster="$LAST_CLUSTER"
            log_info "已加载上次使用的集群: $cluster"
        fi
        if [[ -n "$LAST_NAMESPACE" ]]; then
            current_ns="$LAST_NAMESPACE"
        fi
    fi
}

# 记录命令历史
add_to_history() {
    mkdir -p "$(dirname "$HISTORY_FILE")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$HISTORY_FILE"
}

# 显示命令历史
show_history() {
    if [[ -f "$HISTORY_FILE" ]]; then
        echo -e "${CYAN}📜 最近执行的命令:${NC}"
        tail -10 "$HISTORY_FILE" | nl
    else
        log_warn "暂无历史记录"
    fi
}

# 集群连通性检查
check_cluster_health() {
    log_info "正在检查集群连通性..."
    if timeout 5 kubectl --kubeconfig="$cluster" cluster-info &>/dev/null; then
        log_success "集群连接正常"
        echo -e "${WHITE}集群信息:${NC}"
        kubectl --kubeconfig="$cluster" cluster-info | head -3
        echo ""
        kubectl --kubeconfig="$cluster" get nodes --no-headers 2>/dev/null | wc -l | xargs echo "节点数量:"
    else
        log_error "集群连接失败，请检查配置文件或网络"
        return 1
    fi
}

# ==============================
# 🔐 高危操作密码验证系统（新增）
# ==============================

setup_dangerous_password() {
    # 检查是否已设置
    if ! grep -q "DANGEROUS_PASSWORD_HASH" "$CONFIG_FILE" 2>/dev/null; then
        echo ""
        log_warn "🔒 首次使用：请设置高危操作密码（用于 delete / scale to 0 / force 等操作）"
        read -s -p "设置密码（至少6位）: " pwd1
        echo ""
        read -s -p "确认密码: " pwd2
        echo ""
        if [[ "$pwd1" != "$pwd2" ]]; then
            log_error "两次输入不一致，跳过设置（下次启动会再次提示）"
            return 1
        fi
        if [[ ${#pwd1} -lt 6 ]]; then
            log_error "密码长度至少 6 位"
            return 1
        fi
        pwd_hash=$(echo -n "$pwd1" | sha256sum | awk '{print $1}')
        echo "DANGEROUS_PASSWORD_HASH=$pwd_hash" >> "$CONFIG_FILE"
        log_success "密码设置成功！请牢记此密码。"
    fi
}

verify_dangerous_password() {
    # 从配置加载哈希
    local pwd_hash
    pwd_hash=$(grep "DANGEROUS_PASSWORD_HASH" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)

    if [[ -z "$pwd_hash" ]]; then
        log_error "未设置高危操作密码，请重启脚本初始化设置"
        return 1
    fi

    local attempt=3
    while [[ $attempt -gt 0 ]]; do
        read -s -p "🔐 请输入高危操作密码 (剩余 $attempt 次): " input
        echo ""
        input_hash=$(echo -n "$input" | sha256sum | awk '{print $1}')

        if [[ "$input_hash" == "$pwd_hash" ]]; then
            log_success "密码验证通过"
            return 0
        else
            attempt=$((attempt - 1))
            log_error "密码错误，剩余 $attempt 次"
        fi
    done

    log_error "密码验证失败，操作已取消"
    return 1
}

# ==============================
# 🎯 核心交互函数（fzf + 编辑支持）
# ==============================

# 预览并允许编辑命令
preview_and_edit_command() {
    local cmd="$1"
    if [[ -z "$cmd" ]]; then
        log_error "命令为空，无法预览"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}🔍 即将执行命令:${NC}"
    echo -e "${WHITE}$cmd${NC}"
    echo ""

    read -p "按 Enter 执行，输入 'e' 编辑，输入 'c' 取消: " choice

    case "$choice" in
        e|E)
            if [[ -n "$EDITOR" ]] && command -v "$EDITOR" >/dev/null 2>&1; then
                local tmpfile
                tmpfile=$(mktemp) || { log_error "无法创建临时文件"; return 1; }
                echo "$cmd" > "$tmpfile"
                "$EDITOR" "$tmpfile" && cmd=$(cat "$tmpfile" | tr -d '\r\n')
                rm -f "$tmpfile"
            else
                read -e -i "$cmd" -p "编辑命令: " cmd
            fi
            echo ""
            echo -e "${GREEN}✅ 编辑后命令:${NC}"
            echo -e "${WHITE}$cmd${NC}"
            echo ""
            ;;
        c|C)
            log_info "操作已取消"
            return 1
            ;;
        *)
            # 默认执行
            ;;
    esac

    return 0
}

# 选择命名空间（fzf）
choose_namespace() {
    local show_all=false
    [[ "$1" == "show_all" ]] && show_all=true

    local ns_list
    ns_list=$(kubectl --kubeconfig="$cluster" get ns --no-headers 2>/dev/null | awk '{print $1}' | sort)

    if [[ -z "$ns_list" ]]; then
        log_error "无法获取命名空间列表，请检查集群连接"
        return 1
    fi

    local options=("default" "当前: $current_ns")
    [[ "$show_all" == true ]] && options+=("所有命名空间 (-A)")
    mapfile -t ns_arr <<< "$ns_list"
    options+=("${ns_arr[@]}")

    echo -e "${CYAN}📦 请选择命名空间 (当前: $current_ns):${NC}"
    local selected
    selected=$(printf '%s\n' "${options[@]}" | fzf --height 40% --prompt="命名空间> " --border)

    if [[ -z "$selected" ]]; then
        log_warn "未选择命名空间，保持当前: $current_ns"
        ns_opt="-n $current_ns"
        return 0
    elif [[ "$selected" == "default" ]]; then
        current_ns="default"
        ns_opt="-n default"
    elif [[ "$selected" == "当前: $current_ns" ]]; then
        ns_opt="-n $current_ns"
    elif [[ "$selected" == "所有命名空间 (-A)" ]]; then
        ns_opt="-A"
    else
        current_ns="$selected"
        ns_opt="-n $current_ns"
    fi

    save_config
    log_success "命名空间已切换为: $current_ns"
}

# 选择资源（fzf + 状态着色 + 预览）
choose_resource() {
    local type=$1
    local name_list
    name_list=$(kubectl --kubeconfig="$cluster" get "$type" $ns_opt --no-headers 2>/dev/null)

    if [[ -z "$name_list" ]]; then
        log_warn "没有找到任何 $type"
        resource_name=""
        return 1
    fi

    local preview_cmd="kubectl --kubeconfig='$cluster' describe $type {1} $ns_opt 2>/dev/null | head -20"
    local colored_list=""

    while IFS= read -r line; do
        local name=$(echo "$line" | awk '{print $1}')
        local status=$(echo "$line" | awk '{print $3}')
        local color=""

        case "$status" in
            Running|Ready) color="${GREEN}" ;;
            Pending|ContainerCreating) color="${YELLOW}" ;;
            *) color="${RED}" ;;
        esac

        colored_list+="$color$name${NC} ($status)\n"
    done <<< "$name_list"

    echo -e "${CYAN}📋 请选择 $type:${NC}"
    resource_name=$(echo -e "$colored_list" | fzf \
        --height 50% \
        --prompt="$type> " \
        --border \
        --ansi \
        --preview="$preview_cmd" \
        --preview-window=right:60% \
        --reverse \
        | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | awk '{print $1}')

    if [[ -z "$resource_name" ]]; then
        log_warn "未选择资源"
        return 1
    fi

    log_success "已选择: $resource_name"
}

# 选择额外参数
choose_extra_opts() {
    echo -e "${CYAN}🔧 可选额外参数:${NC}"
    echo " 1) -o wide (详细信息)"
    echo " 2) -o yaml (YAML格式)"
    echo " 3) -o json (JSON格式)"
    echo " 4) --show-labels (显示标签)"
    echo " 5) --previous (上一次日志)"
    echo " 6) -f (实时跟踪日志)"
    echo " 7) --watch (监控变化)"
    echo " 8) 无"
    read -p "👉 请选择参数: " opt_choice
    case $opt_choice in
        1) extra="-o wide" ;;
        2) extra="-o yaml" ;;
        3) extra="-o json" ;;
        4) extra="--show-labels" ;;
        5) extra="--previous" ;;
        6) extra="-f" ;;
        7) extra="--watch" ;;
        *) extra="" ;;
    esac
}

# ==============================
# 🔄 批量操作（已集成密码验证）
# ==============================

batch_operations() {
    echo -e "${PURPLE}🔄 批量操作:${NC}"
    echo " 1) 批量删除pods"
    echo " 2) 批量重启deployment"
    echo " 3) 批量扩缩容"
    echo " 4) 返回主菜单"
    read -p "👉 请选择: " batch_choice

    case $batch_choice in
        1) # 批量删除pods（高危）
            choose_namespace
            read -p "输入pod名称模式 (支持通配符, 如: app-*): " pattern
            matching_pods=$(kubectl --kubeconfig="$cluster" get pods $ns_opt --no-headers | awk '{print $1}' | grep "$pattern")
            if [[ -n "$matching_pods" ]]; then
                echo "匹配的pods:"
                echo "$matching_pods"
                read -p "确认删除以上pods? (y/n): " confirm
                if [[ "$confirm" == "y" ]]; then
                    # 🔐 新增：高危操作密码验证
                    verify_dangerous_password || continue
                    cmd="echo '$matching_pods' | xargs kubectl --kubeconfig=\"$cluster\" delete pod $ns_opt"
                    preview_and_edit_command "$cmd" && eval "$cmd"
                fi
            else
                log_warn "未找到匹配的pods"
            fi
            ;;
        2) # 批量重启deployment（非高危）
            choose_namespace
            kubectl --kubeconfig="$cluster" get deploy $ns_opt --no-headers | awk '{print $1}' | while read deploy; do
                read -p "重启 deployment $deploy ? (y/n): " confirm
                if [[ "$confirm" == "y" ]]; then
                    cmd="kubectl --kubeconfig=\"$cluster\" rollout restart deployment \"$deploy\" $ns_opt"
                    preview_and_edit_command "$cmd" && eval "$cmd"
                fi
            done
            ;;
        3) # 批量扩缩容（检查是否缩容到0）
            choose_namespace
            read -p "输入目标副本数: " replicas
            if [[ "$replicas" -eq 0 ]]; then
                log_warn "⚠️  检测到扩缩容至 0，属于高危操作"
                # 🔐 新增：高危操作密码验证
                verify_dangerous_password || continue
            fi
            kubectl --kubeconfig="$cluster" get deploy $ns_opt --no-headers | awk '{print $1}' | while read deploy; do
                read -p "将 $deploy 扩缩容至 $replicas 个副本? (y/n): " confirm
                if [[ "$confirm" == "y" ]]; then
                    cmd="kubectl --kubeconfig=\"$cluster\" scale deployment \"$deploy\" --replicas=\"$replicas\" $ns_opt"
                    preview_and_edit_command "$cmd" && eval "$cmd"
                fi
            done
            ;;
    esac
}

# ==============================
# 📊 监控和诊断
# ==============================

monitoring_diagnostics() {
    echo -e "${PURPLE}📊 监控和诊断:${NC}"
    echo " 1) 集群资源使用概览"
    echo " 2) 节点详细信息"
    echo " 3) Pod故障排查"
    echo " 4) 网络诊断"
    echo " 5) 存储状态检查"
    echo " 6) 事件监控"
    echo " 7) 返回主菜单"
    read -p "👉 请选择: " monitor_choice

    case $monitor_choice in
        1)
            log_info "获取集群资源使用情况..."
            echo -e "${WHITE}=== 节点资源使用 ===${NC}"
            kubectl --kubeconfig="$cluster" top nodes 2>/dev/null || log_warn "metrics-server可能未安装"
            echo -e "${WHITE}=== Pod资源使用 TOP10 ===${NC}"
            kubectl --kubeconfig="$cluster" top pods -A 2>/dev/null | head -11 || log_warn "metrics-server可能未安装"
            ;;
        2)
            local nodes
            nodes=$(kubectl --kubeconfig="$cluster" get nodes --no-headers | awk '{print $1}')
            echo "选择节点:"
            local node
            node=$(echo "$nodes" | fzf --prompt="节点> ")
            [[ -n "$node" ]] && kubectl --kubeconfig="$cluster" describe node "$node"
            ;;
        3)
            choose_namespace
            echo "查找故障Pod..."
            kubectl --kubeconfig="$cluster" get pods $ns_opt --field-selector=status.phase!=Running --no-headers | while read line; do
                if [[ -n "$line" ]]; then
                    local pod_name=$(echo "$line" | awk '{print $1}')
                    local status=$(echo "$line" | awk '{print $3}')
                    log_error "发现故障Pod: $pod_name (状态: $status)"
                    read -p "查看详细信息? (y/n): " detail
                    if [[ "$detail" == "y" ]]; then
                        kubectl --kubeconfig="$cluster" describe pod "$pod_name" $ns_opt
                        read -p "查看日志? (y/n): " logs
                        if [[ "$logs" == "y" ]]; then
                            kubectl --kubeconfig="$cluster" logs "$pod_name" $ns_opt --tail=50
                        fi
                    fi
                fi
            done
            ;;
        4)
            log_info "网络服务状态检查..."
            kubectl --kubeconfig="$cluster" get svc -A | grep -E "(LoadBalancer|NodePort|ClusterIP)"
            echo ""
            log_info "Ingress状态检查..."
            kubectl --kubeconfig="$cluster" get ingress -A 2>/dev/null || log_warn "未找到Ingress资源"
            ;;
        5)
            log_info "PV/PVC状态检查..."
            kubectl --kubeconfig="$cluster" get pv
            echo ""
            kubectl --kubeconfig="$cluster" get pvc -A
            ;;
        6)
            choose_namespace
            echo "最近事件 (按时间倒序):"
            kubectl --kubeconfig="$cluster" get events $ns_opt --sort-by='.lastTimestamp' | tail -20
            ;;
    esac
}

# ==============================
# ⚡ 快捷操作（已集成密码验证）
# ==============================

quick_actions() {
    echo -e "${PURPLE}⚡ 快捷操作:${NC}"
    echo " 1) 重启deployment"
    echo " 2) 扩缩容"
    echo " 3) 端口转发"
    echo " 4) 复制文件到Pod"
    echo " 5) 从Pod复制文件"
    echo " 6) 应用YAML文件"
    echo " 7) 创建临时调试Pod"
    echo " 8) 返回主菜单"
    read -p "👉 请选择: " quick_choice

    case $quick_choice in
        1)
            choose_namespace
            choose_resource "deployments"
            [[ -z "$resource_name" ]] && return
            cmd="kubectl --kubeconfig=\"$cluster\" rollout restart deployment \"$resource_name\" $ns_opt"
            preview_and_edit_command "$cmd" && eval "$cmd"
            log_success "Deployment $resource_name 重启已触发"
            ;;
        2)
            choose_namespace
            choose_resource "deployments"
            [[ -z "$resource_name" ]] && return
            read -p "输入目标副本数: " replicas
            if [[ "$replicas" -eq 0 ]]; then
                log_warn "⚠️  检测到扩缩容至 0，属于高危操作"
                # 🔐 新增：高危操作密码验证
                verify_dangerous_password || continue
            fi
            cmd="kubectl --kubeconfig=\"$cluster\" scale deployment \"$resource_name\" --replicas=\"$replicas\" $ns_opt"
            preview_and_edit_command "$cmd" && eval "$cmd"
            ;;
        3)
            choose_namespace
            choose_resource "pods"
            [[ -z "$resource_name" ]] && return
            read -p "输入本地端口: " local_port
            read -p "输入Pod端口: " pod_port
            cmd="kubectl --kubeconfig=\"$cluster\" port-forward \"$resource_name\" \"$local_port:$pod_port\" $ns_opt"
            preview_and_edit_command "$cmd" && eval "$cmd"
            ;;
        4)
            choose_namespace
            choose_resource "pods"
            [[ -z "$resource_name" ]] && return
            read -p "本地文件路径: " local_file
            read -p "Pod内目标路径: " pod_path
            cmd="kubectl --kubeconfig=\"$cluster\" cp \"$local_file\" \"$resource_name:$pod_path\" $ns_opt"
            preview_and_edit_command "$cmd" && eval "$cmd"
            ;;
        5)
            choose_namespace
            choose_resource "pods"
            [[ -z "$resource_name" ]] && return
            read -p "Pod内文件路径: " pod_file
            read -p "本地目标路径: " local_path
            cmd="kubectl --kubeconfig=\"$cluster\" cp \"$resource_name:$pod_file\" \"$local_path\" $ns_opt"
            preview_and_edit_command "$cmd" && eval "$cmd"
            ;;
        6)
            read -p "YAML文件路径: " yaml_file
            if [[ -f "$yaml_file" ]]; then
                cmd="kubectl --kubeconfig=\"$cluster\" apply -f \"$yaml_file\""
                preview_and_edit_command "$cmd" && eval "$cmd"
            else
                log_error "文件不存在: $yaml_file"
            fi
            ;;
        7)
            choose_namespace
            read -p "Pod名称 (默认: debug-pod): " debug_name
            [[ -z "$debug_name" ]] && debug_name="debug-pod"
            cmd="kubectl --kubeconfig=\"$cluster\" run \"$debug_name\" $ns_opt --image=busybox:latest --rm -it --restart=Never -- /bin/sh"
            preview_and_edit_command "$cmd" && eval "$cmd"
            ;;
    esac
}

# ==============================
# 🌐 集群选择
# ==============================

choose_cluster() {
    if [[ -n "$cluster" ]] && [[ -f "$cluster" ]]; then
        read -p "是否继续使用集群 $cluster ? (y/n, 默认y): " continue_cluster
        if [[ "$continue_cluster" != "n" ]]; then
            check_cluster_health && return 0
        fi
    fi

    echo -e "${CYAN}🌐 请选择集群:${NC}"
    cluster=$(printf '%s\n' "${clusters[@]}" | fzf --height 40% --prompt="集群> " --border)

    if [[ -z "$cluster" ]]; then
        log_error "未选择集群"
        return 1
    fi

    if check_cluster_health; then
        save_config
        log_success "集群已切换为: ${cluster##*/}"
    else
        return 1
    fi
}

# ==============================
# 🎯 主菜单（delete 已集成密码验证）
# ==============================

main_menu() {
    while true; do
        echo ""
        echo -e "${WHITE}=== 🎯 Kubernetes 管理工具 ===${NC}"
        echo -e "${CYAN}当前集群: ${cluster##*/}${NC}"
        echo -e "${CYAN}当前命名空间: $current_ns${NC}"
        echo ""
        echo " 1)  📋 get (查看资源)"
        echo " 2)  🔍 describe (描述资源)"
        echo " 3)  📜 logs (查看日志)"
        echo " 4)  💻 exec (进入容器)"
        echo " 5)  📊 top (资源使用)"
        echo " 6)  🗑️  delete (删除资源)"
        echo " 7)  ⚡ 快捷操作"
        echo " 8)  🔄 批量操作"
        echo " 9)  📊 监控诊断"
        echo "10) 🔧 自定义命令"
        echo "11) 🌐 切换集群"
        echo "12) 📦 切换命名空间"
        echo "13) 📜 命令历史"
        echo "14) ⚙️  配置管理"
        echo "15) 👋 退出"

        read -p "👉 请输入序号: " choice

        case $choice in
            1)
                read -p "请输入资源类型 (pods/nodes/ns/deploy/svc/events...): " res
                [[ -z "$res" ]] && res="pods"
                choose_namespace show_all
                choose_extra_opts
                cmd="kubectl --kubeconfig=\"$cluster\" get \"$res\" $ns_opt $extra"
                preview_and_edit_command "$cmd" && eval "$cmd"
                add_to_history "$cmd"
                ;;
            2)
                read -p "请输入资源类型 (node/pod/deploy/...): " res
                [[ "$res" != "node" ]] && [[ "$res" != "nodes" ]] && choose_namespace
                choose_resource "$res"
                [[ -z "$resource_name" ]] && continue
                cmd="kubectl --kubeconfig=\"$cluster\" describe \"$res\" \"$resource_name\" $ns_opt"
                preview_and_edit_command "$cmd" && eval "$cmd"
                add_to_history "$cmd"
                ;;
            3)
                choose_namespace
                choose_resource "pods"
                [[ -z "$resource_name" ]] && continue
                choose_extra_opts
                read -p "是否指定容器名？(直接回车跳过): " cname
                [[ -n "$cname" ]] && container_opt="-c $cname" || container_opt=""
                read -p "显示日志条数 (默认100): " tailn
                [[ -z "$tailn" ]] && tailn=100
                cmd="kubectl --kubeconfig=\"$cluster\" logs \"$resource_name\" $ns_opt $container_opt $extra --tail=\"$tailn\""
                preview_and_edit_command "$cmd" && eval "$cmd"
                add_to_history "$cmd"
                ;;
            4)
                choose_namespace
                choose_resource "pods"
                [[ -z "$resource_name" ]] && continue
                containers=$(kubectl --kubeconfig="$cluster" get pod "$resource_name" $ns_opt -o jsonpath='{.spec.containers[*].name}')
                container_arr=($containers)
                container_opt=""
                if [[ ${#container_arr[@]} -gt 1 ]]; then
                    echo "Pod中有多个容器:"
                    select cname in "${container_arr[@]}"; do
                        container_opt="-c $cname"
                        break
                    done
                fi
                cmd="kubectl --kubeconfig=\"$cluster\" exec -it $ns_opt \"$resource_name\" $container_opt -- /bin/bash"
                preview_and_edit_command "$cmd" || continue
                if ! eval "$cmd"; then
                    log_warn "/bin/bash 失败，尝试 /bin/sh"
                    cmd="${cmd%/bin/bash}/bin/sh"
                    eval "$cmd"
                fi
                add_to_history "$cmd"
                ;;
            5)
                echo "📊 1) node   2) pod"
                read -p "👉 请选择: " t
                if [[ "$t" == "1" ]]; then
                    cmd="kubectl --kubeconfig=\"$cluster\" top node"
                    preview_and_edit_command "$cmd" && eval "$cmd"
                else
                    choose_namespace
                    cmd="kubectl --kubeconfig=\"$cluster\" top pod $ns_opt"
                    preview_and_edit_command "$cmd" && eval "$cmd"
                fi
                ;;
            6) # delete（高危）
                read -p "请输入资源类型 (pod/deploy/...): " res
                choose_namespace
                choose_resource "$res"
                [[ -z "$resource_name" ]] && continue
                echo -e "${RED}⚠️  确认删除 $res/$resource_name ?"
                echo "1) 是  2) 否  3) 强制删除"
                read -p "👉 请选择: " confirm
                case $confirm in
                    1|3)
                        # 🔐 新增：高危操作密码验证
                        verify_dangerous_password || continue

                        if [[ "$confirm" == "1" ]]; then
                            cmd="kubectl --kubeconfig=\"$cluster\" delete \"$res\" \"$resource_name\" $ns_opt"
                        else
                            cmd="kubectl --kubeconfig=\"$cluster\" delete \"$res\" \"$resource_name\" $ns_opt --force --grace-period=0"
                        fi

                        preview_and_edit_command "$cmd" && eval "$cmd"
                        add_to_history "$cmd"
                        ;;
                    *)
                        log_info "已取消删除"
                        ;;
                esac
                ;;
            7) quick_actions ;;
            8) batch_operations ;;
            9) monitoring_diagnostics ;;
            10)
                read -p "请输入完整的 kubectl 子命令 (不需要带 --kubeconfig): " user_cmd
                cmd="kubectl --kubeconfig=\"$cluster\" $user_cmd"
                preview_and_edit_command "$cmd" && eval "$cmd"
                add_to_history "$cmd"
                ;;
            11) choose_cluster ;;
            12) choose_namespace show_all ;;
            13) show_history ;;
            14)
                echo "配置管理:"
                echo " 1) 查看当前配置"
                echo " 2) 重置配置（含密码）"
                read -p "选择: " config_choice
                case $config_choice in
                    1) [[ -f "$CONFIG_FILE" ]] && cat "$CONFIG_FILE" || echo "无配置文件" ;;
                    2) 
                        rm -f "$CONFIG_FILE" "$HISTORY_FILE"
                        log_success "配置和密码已重置，下次启动需重新设置"
                        ;;
                esac
                ;;
            15)
                log_success "再见！"
                exit 0
                ;;
            *)
                log_error "无效选项，请重新输入。"
                ;;
        esac

        echo ""
        read -p "按 Enter 继续，或输入 'q' 退出: " continue_choice
        [[ "$continue_choice" == "q" ]] && exit 0
    done
}

# ==============================
# 🚀 启动检查（新增密码设置）
# ==============================

startup_checks() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在PATH中"
        exit 1
    fi
    if ! command -v fzf &> /dev/null; then
        log_error "fzf 未安装，请先安装：https://github.com/junegunn/fzf"
        exit 1
    fi
    log_success "Kubernetes 管理工具启动成功"
}

# ==============================
# 🎬 执行入口（新增密码初始化）
# ==============================

startup_checks
load_config
setup_dangerous_password  # 👈 新增：引导设置密码
choose_cluster
main_menu
