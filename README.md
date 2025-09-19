# manager_k8sctl
# 🚀 k8s-manager — 企业级 Kubernetes 终端管理工具

> 🛡️ 唯一集成 **fzf 模糊搜索 + 高危操作密码验证 + 命令预览编辑** 的交互式 k8s 管理工具  
> ⚡ 30 秒安装，立即提升 10 倍操作效率，新人秒上手，老手更高效！
> ## ✨ 核心功能

- 🔍 **fzf 模糊搜索** — 秒选 Pod/Deployment/Namespace
- ✍️ **命令预览编辑** — 执行前自由修改命令（支持 vim/nano）
- 🔐 **高危操作密码锁** — 删除/强制删除/缩容到0 需密码验证
- 🔄 **批量操作菜单** — 批量删 Pod、重启 Deployment、统一扩缩容
- 📊 **监控诊断面板** — 资源使用、故障排查、事件监控一站式解决
- 📜 **操作历史审计** — 自动记录所有命令，支持回放
- 🎨 **彩色交互菜单** — Emoji + ANSI 颜色，视觉友好

- ⚙️ 配置别名（推荐）
bash
echo "alias k8s='~/path/to/k8s-manager.sh'" >> ~/.bashrc
echo "export EDITOR=vim" >> ~/.bashrc
source ~/.bashrc

MIT License 

Copyright (c) 2025 mengxinghun9657

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
