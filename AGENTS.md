# AGENTS.md — dotfiles (chezmoi)

chezmoi 源目录 `~/.local/share/chezmoi`，目标根 `~`（Windows 为 `%USERPROFILE%`），远端 `git@github.com:kicre/dotfiles.git`，分支 `main`。
Linux 桌面与一小组 Windows 配置共用同一套源文件。

## 最小化

本仓库默认倾向是"少"，以下为硬要求：

- 无实质影响的配置不加：不预埋开关、不为假想用途加分支、不加"以后可能用得上"的注释或被注释掉的代码。
- 新增一层（模板、`include`、脚本、external 条目）必须换来当下具体收益，否则复用现有机制。
- 能写在现成文件里就不新建文件，能一行写完就不拆结构。
- 发现多余配置先指出并说明影响，确认后再删，不"顺手清理"。

## 布局

- 源文件名前缀就是行为，改名等于改行为：`dot_` 前导点、`executable_` 可执行位、`private_` 0600、`exact_` 目录不做增量、`encrypted_` age 加密、`.tmpl` 后缀 Go 模板。
- `dot_config/<app>/` 是 Linux 目标，`AppData/Roaming/<app>/` 是 Windows 目标；`Documents/PowerShell/`、`startup.vbs` 仅 Windows。
- 共享正文放 `.chezmoitemplates/<app>/<file>.tmpl`，目标文件只留一行转发：

  ```
  {{- template "alacritty/alacritty.toml.tmpl" . -}}
  ```

  改内容改 `.chezmoitemplates` 里的那份；两侧 stub 指向同一正文，不要各写一份。

## 模板

- OS 分支统一用 `{{ if eq .chezmoi.os "windows" }}` / `{{ if ne .chezmoi.os "windows" }}`；路径用 `{{ .chezmoi.homeDir }}`，不硬编码家目录。
- 独占一行的控制语句用 `{{-` 与 `-}}` 裁空白，否则生成的配置文件会多出空行。
- 同一逻辑不要在 Linux 与 Windows 两份里各实现一遍：抽到 `.chezmoitemplates`，用 `.chezmoi.os` 分支。
- 外部命令与插件先 `command -v` / `hash` 判断再启用，缺失时只降级，不能让登录或 shell 报错。

## 忽略与加密

- `.chezmoiignore` 按 OS 排除条目，并在 `key.txt` 缺失时排除整段 `.ssh/*`。源目录里任何不该铺到 `~` 的文件（包括本文件）都必须写进 `.chezmoiignore`，否则 `chezmoi apply` 会把它创建出来。
- 密钥只以 `encrypted_*.age` 入库；解密身份 `~/.config/chezmoi/key.txt` 永不进仓库，且必须是 0600 —— chezmoi 拒绝 group 或 world 可读的身份文件。
- 不打印、不复制私钥，不改 age recipient。

## 外部依赖

- `.chezmoiexternal.toml.tmpl` 声明 zsh / bash 插件与主题包：`type = "archive"`、`exact = true`、`stripComponents = 1`、`refreshPeriod = "168h"`。
- 这些目录由 chezmoi 下载生成，不提交、不手工编辑。新增插件走 external 条目，不要在仓库里放 vendored 副本。

## 验证

改完至少跑前两条（都只读，不写 `$HOME`）：

- 模板能渲染：`chezmoi execute-template --file <源文件路径>`
- Windows 分支：`chezmoi --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file <源文件路径>`
- shell 语法：`chezmoi execute-template --file dot_zshrc.tmpl | zsh -n /dev/stdin`
- 差量预览：`chezmoi diff`
- 环境自检：`chezmoi doctor`

`chezmoi apply` 会覆盖真实家目录文件，属"先确认"操作：先给出 `chezmoi diff` 内容再问。
两条容易被误判的信号：`dot_config/serenity/config.json.tmpl` 是 JSONC（含 `//`），`jq` 校验失败不代表文件损坏；`chezmoi managed` 会展开 external，条目数远多于受管文件数。

## 协同

- 一次提交一个主题（一个应用，或一类改动）。历史提交是简短中文（如 `添加插件判断`），保持同样风格。
- 只提交本次自己改的路径。工作区里别人或历史的未提交改动，既不并入自己的提交，也不还原。
- 禁 `git add -A` / `git add .` / `reset --hard` / `checkout .` / `clean -fd` / `stash`。
