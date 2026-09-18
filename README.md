# Local Reader iOS — development baseline

独立实现的离线 iOS 阅读器开发工程。**尚未完成目标阅读体验的一比一复刻。**

当前代码：本地书架持久化、UTF-8/UTF-16 TXT 导入、重复检测、临时文本阅读页面、ZIP 解压及路径/CRC 校验。
EPUB 接入、Core Text 分页、定制翻页、阅读进度、书签与界面对照尚未完成；模型中的字段不代表相应 UI 已实现。
不含第三方 APK、反编译代码、字体或品牌素材，不连接小说服务。

## GitHub Actions

进入 **Actions → iOS build and simulator tests → Run workflow**。
main 分支的代码/CI 修改也会触发构建；并发运行会取消同分支旧任务。

使用 GitHub 托管 `macos-15`、Xcode 16.4，不需要本地 Mac、签名证书或 Apple ID。
工作流会检查工具链，生成 Xcode 工程，运行 XCTest，在模拟器启动 App、截图，并编译未签名 iPhone 版本。
所有步骤通过才算 CI 成功；日志和测试结果保留 7 天。

下载运行页底部的 `ios-build-*` artifact：
- `LocalReader-simulator.app.zip`：仅供模拟器，不能安装到 iPhone。
- `LocalReader-UNSIGNED-device.app.zip`：未签名设备构建，不能直接安装到 iPhone，也不是可直接安装的 IPA。
- `Tests.xcresult`、日志、`simulator.png`：实际执行证据；截图仅验证开发版启动，不证明与参考 App 一致。

真机安装必须另行配置合法签名。不要将证书、密码、私钥或 provisioning profile 提交到公开仓库。

## 本地构建（有 Mac 时）

```bash
python3 Scripts/generate_project.py
open LocalReader.xcodeproj
```

最低 iOS 16。生成器只依赖 Python 标准库；不需要 CocoaPods、第三方 Swift 包或 XcodeGen。
公开仓库用于编译独立工程；逆向研究材料留在本地，不随仓库发布。

## 验收边界

CI 通过只代表当前开发基线通过相应测试；不代表完整阅读器、目标排版一致性、原生算法逆向或真机性能已验收。
本项目尚未选择开源许可证；公开可见不等于额外授予第三方素材或代码的使用权。
