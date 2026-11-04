# Stats Trio

一个精简的 macOS 菜单栏应用：将 CPU、内存、温度／系统总功率、网速和 Trio 图标组合排列，各区域独立打开相应详情。

- 按参考布局预留固定栏位与均衡留白；数字变化不改变其他区域位置，保留独立点击、弹窗互斥和 Escape 收起。
- 网速显示两行数值，无红蓝圆点。
- 电池充满时显示完整绿环，顶部仅在实际充电时显示闪电。
- Trio 默认综合面板包含电池、网络、蓝牙设备／电量、音量／输出和输入法。
- 电池摘要显示电源适配器报告的功率；网络摘要显示当前协商速率。不可读取时明确显示不可用。
- 与原 Stats 使用不同的应用身份和偏好，不覆盖原应用，也不迁入登录项或凭据。

## 下载和安装

在本仓库 Releases 下载 `Stats-Trio-v0.1.2-macOS-arm64.zip`，解压后把 `Stats Trio.app` 拖入“应用程序”，再打开。

适用于 Apple Silicon、macOS 15+；已在 M1 / macOS 15.7.7 验证。当前为本地 ad-hoc 签名的预览版，未经 Apple 公证；系统权限和首次运行由 macOS 正常流程处理。重新构建后蓝牙授权可能需要重新确认。没有自动更新。

重新打开应用可进入设置；设置窗口激活后，也可通过“窗口”菜单打开各项详情。仅主动启用“开机启动”时才注册本应用的登录项。

## 构建与验证

需要 macOS、Apple Command Line Tools、Python 3。无需安装第三方 Python 包。受支持入口为：

```sh
Scripts/build-local.sh
Scripts/test-local.sh
Scripts/test-embedded.sh
Scripts/test-popup.sh
```

产物位于 `build/Stats Trio.app`。原上游 Xcode 工程作为来源保留，尚未配置为本应用的发行 scheme。

测试使用生产源码编译的原生断言和 AppKit 组件测试，以及 Python 构建行为测试。17 项原生行为用例、4 项 Python 用例、真实固定栏位／矮屏弹窗和嵌入组件测试通过。真实多屏切换、睡眠唤醒、所有外接硬件及物理菜单栏鼠标点击尚未全面验收。

仓库是发行用源码快照，不包含开发机器诊断、个人配置或本机 Git 历史。

## 来源及许可证

- [Stats](https://github.com/exelban/stats)：MIT，基于 v3.0.5 / `2fff0dfb5e58fe9ce43636939d6f9cc001ff6a0b`。
- [Status Trio](https://github.com/lingyired/status-trio)：Apache-2.0，基于 `ddd728eeb50e992721158dfc64642841edf01b40`。
- 保留原许可证及第三方声明；App 内 `Contents/Resources/Licenses/` 随附五份声明。

## 回退

退出并移除 Stats Trio 后可继续使用原 Stats；两者偏好和数据目录独立。
