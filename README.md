# 🚀 manager_k8sctl — 企业级 Kubernetes 终端管理神器

> 🛡️ **唯一集成 `fzf` 模糊搜索 + 高危操作密码验证 + 命令预览编辑** 的交互式 Kubernetes 管理工具  
> ⚡ **30 秒安装 · 10 倍效率提升 · 新人秒上手 · 老手更高效 · 企业级安全防护**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.20%2B-blue)](https://kubernetes.io)

---

## ✨ 为什么选择 `manager_k8sctl`？

还在为这些烦恼吗？

- ❌ 手滑误删生产 Pod？
- ❌ Pod 名称太长记不住？
- ❌ 想加个参数但不会写完整命令？
- ❌ 要批量操作却只能一个个复制粘贴？
- ❌ 新同事不会用 `kubectl`？

👉 **`manager_k8sctl` 一次性解决所有痛点！**

---

## 🌟 核心功能亮点

| 功能 | 描述 | 价值 |
|------|------|------|
| 🔍 **fzf 模糊搜索** | 秒级定位 Pod / Deployment / Namespace，支持状态着色 + 实时预览 | 告别 `kubectl get pods \| grep xxx` |
| ✍️ **命令预览编辑** | 执行前自由修改命令，支持 `vim` / `nano` / 行内编辑 | 随时加参数、改字段、管道重定向 |
| 🔐 **高危操作密码锁** | 删除 / 强制删除 / 缩容到 0 前强制密码验证（SHA256 哈希存储） | 企业级安全防护，杜绝误操作 |
| 🔄 **批量操作菜单** | 一键批量删除 Pod、重启 Deployment、统一扩缩容 | 运维效率提升 10 倍 |
| 📊 **监控诊断面板** | 资源使用、节点详情、故障排查、事件监控、网络/存储状态 | 一站式诊断，无需切换工具 |
| 📜 **操作历史审计** | 自动记录所有执行命令 + 时间戳，支持查看最近 10 条 | 操作可追溯，责任可定位 |
| 🎨 **彩色交互菜单** | Emoji + ANSI 颜色 + 清晰导航，视觉友好不疲劳 | 长时间操作也不累眼 |


---

## 📦 快速安装

### 1. 下载脚本

```bash
curl -LO https://github.com/mengxinghun9657-boop/manager_k8sctl.git
chmod +x manager_k8sctl.sh


2. 设置别名 & 编辑器（强烈推荐）
bash
# 添加到 ~/.bashrc（或 ~/.zshrc）
echo "alias k8s='$(pwd)/manager_k8sctl.sh'" >> ~/.bashrc
echo "export EDITOR=vim" >> ~/.bashrc  # 或 nano
source ~/.bashrc

3. 启动工具
bash
k8s

🧩 使用示例
查看 Pod 日志（带模糊搜索 + 命令编辑）
bash

k8s → 选择 3 (logs) → fzf 搜索 "nginx" → 输入密码 → 编辑命令加 "\| grep ERROR" → 执行
批量删除 Pod（带密码验证）
bash

k8s → 选择 8 (批量操作) → 选择 1 (批量删除) → 输入 "app-*" → 确认 → 输入密码 → 执行
重启所有 Deployment（逐个确认）
bash

k8s → 选择 8 → 选择 2 → 逐个按 y 确认重启
⚙️ 配置文件说明
配置文件：~/.k8s-manager-config
存储：最后使用的集群、命名空间、密码哈希
历史记录：~/.k8s-manager-history
记录：所有执行过的命令 + 时间戳
🔐 密码安全：密码以 SHA256 哈希形式存储，绝不保存明文！ 

🤝 贡献与反馈
欢迎提交 Issue 和 Pull Request！

报告 Bug
请求新功能（如 Helm 集成、多集群并行操作）
改进文档
翻译多语言


📜 开源许可证
MIT License

Copyright (c) 2025 mengxinghun9657

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

💬 “最好的工具，是让自己和团队更安全、更高效的工具。” —— manager_k8sctl 作者 
