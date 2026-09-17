# 环境与授权

在独立视频项目执行；Agent 自动完成安装与命令，不把命令交给用户手动操作。先确认 Node >=22.15、ffmpeg/ffprobe、uv 可执行；按系统包管理器安装缺项。Linux 无桌面凭证库时 `platform` 会用用户私有文件，macOS/Windows 用系统凭证库。

```bash
npx skills add hypit-ai/hypit -g
npm init -y
npm install @hypit/hypit@0.2.1
npm install --install-links /absolute/path/to/listenhub-hypit/provider
npx hypit runtime init
```

下文所有 hypit 命令均在该视频项目目录用 `npx hypit` 执行，使用项目锁定的版本；不要依赖全局 PATH。已有项目无需再次 `npm init`。

`runtime init` 默认生成带 HypiHub 的 profile，**先替换再启动**。把 [templates/hypit.runtime.json](templates/hypit.runtime.json) 复制到项目（保留用户已有且需要的其他本地配置），执行 `npx hypit runtime use ./hypit.runtime.json`。仅新项目可整体替换。不要把 npm Distribution 或 hypit 源码复制进 skill 仓；Provider 包已经带 `dist/*.js`，使用者不需要编译。`--install-links` 让 npm 将本地包与其纯 JS 依赖安装进项目，而非依赖外部软链的 node_modules。

读取 ListenHub OpenAPI 配置确认账号与 API base，优先复用该账号本机已有 API key，禁止打印、提交或写进 profile。profile 中 `apiKey` 是 `{store,key}` 引用。通过交互秘密输入，或 Agent 创建的 `0600` 临时秘密文件交给凭证库：

```bash
npx hypit auth login listenhub.local --slot apiKey --from /private/temporary/key-file
npx hypit auth status listenhub.local --json
```

存入后删除临时文件；不把 key 写命令行或日志。生产默认 `https://api.listenhub.ai/openapi`，测试配置换为实际 staging base；账号改变重新报价。无需 HypiHub 登录。

**渲染前必须准备运行时**，新机器不会自带受管 Chrome/OpenCV：

```bash
npx hypit runtime up --runtime ./hypit.runtime.json
npx hypit doctor --runtime ./hypit.runtime.json --json
```

`runtime up` 会自动安装配置所需的本地依赖；这些本地安装不扣 ListenHub 积分。下载慢可先 `--endpoint media.local`、`--endpoint hyperframes.local` 分别准备；要执行图像合成再准备 `image-opencv.local`。用命令输出的安装日志排查，勿将 `MANAGED_PROGRAM_DOWN` 当素材生成故障而重新付费。遇到安装/网络阻塞先解决，确认本地可渲染再提交生成。

拷贝 `templates/` 里需要的 `.svml`、`.svrun`、`styles.svs` 到项目，创建 `assets/`。它们是实际素材位置模板：meme 需要 `pet.mp4`、`music.wav`；旁白需要 `poster.png`、`voice.wav`、`music.wav`、`caption-font.ttf`。素材格式扩展名必须与实际内容一致。旁白图像的 `space:Extent` 要用 probe 得到的真实尺寸，字体文件要覆盖台词字符、与声明字重一致；使用自带/开源字体及其许可，可换为 `.otf/.woff2` 并更新 src。不要把 `.ttc` 改名成 `.ttf`。
